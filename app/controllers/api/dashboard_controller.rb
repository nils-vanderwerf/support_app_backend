module Api
  class DashboardController < ApplicationController
    def show
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user

      if current_user.client
        render json: client_dashboard(current_user.client)
      elsif current_user.support_worker
        render json: worker_dashboard(current_user.support_worker)
      else
        render json: { error: 'No profile found' }, status: :unprocessable_entity
      end
    end

    private

    def client_dashboard(client)
      now = Time.current

      upcoming = Appointment.active
        .where(client_id: client.id)
        .where(date: now..7.days.from_now)
        .order(:date)
        .includes(:support_worker)

      recent = Appointment.active
        .where(client_id: client.id)
        .where(date: 7.days.ago..now)
        .order(date: :desc)
        .includes(:support_worker)

      last_appt = recent.first

      days_since = last_appt ? ((now - last_appt.date) / 1.day).floor : nil

      given_reviews = client.reviews
        .includes(support_worker: :user)
        .order(created_at: :desc)
        .limit(5)

      {
        role: 'client',
        upcoming_appointments: upcoming.as_json(include: :support_worker),
        recent_appointments: recent.as_json(include: :support_worker),
        days_since_last_appointment: days_since,
        total_appointments: Appointment.active.where(client_id: client.id).count,
        health_info: {
          health_conditions: client.health_conditions,
          medication: client.medication,
          allergies: client.allergies,
        },
        given_reviews: given_reviews.as_json(
          only: %i[id rating comment created_at],
          include: { support_worker: { only: %i[id first_name last_name] } }
        ),
      }
    end

    def worker_dashboard(worker)
      now = Time.current
      today_start = now.beginning_of_day
      today_end = now.end_of_day
      week_start = now.beginning_of_week
      week_end = now.end_of_week

      upcoming = Appointment.active
        .where(support_worker_id: worker.id)
        .where(date: now..7.days.from_now)
        .order(:date)
        .includes(:client)

      today = Appointment.active
        .where(support_worker_id: worker.id)
        .where(date: today_start..today_end)
        .order(:date)
        .includes(:client)

      recent = Appointment.active
        .where(support_worker_id: worker.id)
        .where(date: 7.days.ago..now)
        .order(date: :desc)
        .includes(:client)

      hours_this_week = Appointment.active
        .where(support_worker_id: worker.id)
        .where(date: week_start..week_end)
        .sum(:duration)
        .to_f / 60

      total_clients = Appointment.active
        .where(support_worker_id: worker.id)
        .distinct
        .count(:client_id)

      recent_reviews = worker.reviews
        .includes(:client)
        .order(created_at: :desc)
        .limit(3)

      {
        role: 'support_worker',
        upcoming_appointments: upcoming.as_json(include: :client),
        recent_appointments: recent.as_json(include: :client),
        today_appointments: today.as_json(include: :client),
        hours_this_week: hours_this_week.round(1),
        total_clients: total_clients,
        average_rating: worker.average_rating,
        review_count: worker.review_count,
        recent_reviews: recent_reviews.as_json(
          only: %i[id rating comment created_at],
          include: { client: { only: %i[first_name last_name] } }
        ),
      }
    end
  end
end
