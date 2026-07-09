require 'rails_helper'

RSpec.describe AppointmentNote, type: :model do
  def build_note(**attrs)
    appointment = create(:appointment, :past)
    AppointmentNote.new(
      appointment: appointment,
      support_worker_id: appointment.support_worker.id,
      content: 'Session notes content.',
      **attrs
    )
  end

  it 'is valid with appointment, support_worker, and content' do
    expect(build_note).to be_valid
  end

  it 'is invalid without content' do
    expect(build_note(content: '')).not_to be_valid
  end

  it 'belongs to appointment' do
    note = create(:appointment_note)
    expect(note.appointment).to be_a(Appointment)
  end

  it 'belongs to support_worker' do
    note = create(:appointment_note)
    expect(note.support_worker).to be_a(SupportWorker)
  end

  describe 'appointment_id uniqueness' do
    it 'rejects a second note for the same appointment' do
      first = create(:appointment_note)
      duplicate = build_note(appointment: first.appointment)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:appointment_id]).to be_present
    end

    it 'allows notes for different appointments' do
      create(:appointment_note)
      other = build_note
      expect(other).to be_valid
    end
  end
end
