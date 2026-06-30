require 'rails_helper'

RSpec.describe Review, type: :model do
  let(:client) { create(:client) }
  let(:support_worker) { create(:support_worker) }
  let(:past_approved_appointment) do
    create(:appointment, :past, client: client, support_worker: support_worker, status: 'approved')
  end

  def build_review(overrides = {})
    Review.new({
      client: client,
      support_worker: support_worker,
      appointment: past_approved_appointment,
      rating: 5
    }.merge(overrides))
  end

  describe 'validations' do
    it 'is valid with all required attributes' do
      expect(build_review).to be_valid
    end

    context 'rating' do
      it 'is invalid without a rating' do
        expect(build_review(rating: nil)).not_to be_valid
      end

      (1..5).each do |r|
        it "is valid with rating #{r}" do
          expect(build_review(rating: r)).to be_valid
        end
      end

      it 'is invalid with rating 0' do
        expect(build_review(rating: 0)).not_to be_valid
      end

      it 'is invalid with rating 6' do
        expect(build_review(rating: 6)).not_to be_valid
      end
    end

    context 'appointment uniqueness' do
      it 'prevents two reviews for the same appointment' do
        build_review.save!
        duplicate = build_review
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:appointment_id]).to include('already has a review')
      end
    end

    context 'appointment_must_be_past_and_approved' do
      it 'is invalid when appointment is pending' do
        pending_appt = create(:appointment, :pending, client: client, support_worker: support_worker, date: 2.weeks.ago)
        review = build_review(appointment: pending_appt)
        expect(review).not_to be_valid
        expect(review.errors[:appointment]).to include('must be approved')
      end

      it 'is invalid when appointment is in the future' do
        future_appt = create(:appointment, client: client, support_worker: support_worker, status: 'approved', date: 1.week.from_now)
        review = build_review(appointment: future_appt)
        expect(review).not_to be_valid
        expect(review.errors[:appointment]).to include('must be in the past')
      end

      it 'is invalid when client does not match appointment' do
        other_client = create(:client)
        review = build_review(client: other_client)
        expect(review).not_to be_valid
        expect(review.errors[:base]).to include('Client does not match appointment')
      end
    end

    it 'allows a nil comment' do
      expect(build_review(comment: nil)).to be_valid
    end
  end
end
