module Api
  class ReviewsController < ApplicationController
    skip_worker_approval_check # #index is a public ratings listing, open even to logged-out visitors

    def index
      worker = SupportWorker.find(params[:support_worker_id])
      reviews = worker.reviews.includes(:client).order(created_at: :desc)
      render json: reviews.as_json(
        only: %i[id rating comment created_at appointment_id],
        include: { client: { only: %i[id first_name last_name] } }
      )
    end

    def create
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client

      client = current_user.client
      appointment = Appointment.find_by(id: params[:appointment_id])

      return render json: { error: 'Appointment not found' }, status: :not_found unless appointment
      return render json: { error: 'Forbidden' }, status: :forbidden unless appointment.client_id == client.id

      review = Review.new(
        client: client,
        support_worker_id: appointment.support_worker_id,
        appointment: appointment,
        rating: params[:rating],
        comment: params[:comment]
      )

      if review.save
        ReviewMailer.new_review(review).deliver_later
        notify_worker_via_message(review)
        render json: review.as_json(
          only: %i[id rating comment created_at appointment_id],
          include: { client: { only: %i[id first_name last_name] } }
        ), status: :created
      else
        render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      review = Review.find_by(id: params[:id])
      return render json: { error: 'Not found' }, status: :not_found unless review
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client&.id == review.client_id

      if review.update(rating: params[:rating], comment: params[:comment])
        render json: review.as_json(
          only: %i[id rating comment created_at appointment_id],
          include: { client: { only: %i[id first_name last_name] } }
        )
      else
        render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      review = Review.find_by(id: params[:id])
      return render json: { error: 'Not found' }, status: :not_found unless review
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client&.id == review.client_id

      review.destroy
      head :no_content
    end

    private

    def notify_worker_via_message(review)
      conversation = Conversation.find_or_create_by(
        client_id: review.client_id,
        support_worker_id: review.support_worker_id
      )
      stars = '★' * review.rating + '☆' * (5 - review.rating)
      conversation.messages.create!(
        content: "[SYS] #{review.client.first_name} left you a #{review.rating}-star review #{stars}",
        sender_type: 'client',
        sender_id: review.client_id
      )
    end
  end
end
