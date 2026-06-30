class ReviewMailer < ApplicationMailer
  def new_review(review)
    @review = review
    @client = review.client
    @support_worker = review.support_worker
    @appointment = review.appointment
    mail(
      to: @support_worker.email,
      subject: "#{@client.first_name} #{@client.last_name} left you a #{@review.rating}-star review"
    )
  end
end
