require 'rails_helper'

RSpec.describe VisitReport, type: :model do
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown', email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney') }
  let(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: '2026-05-01') }

  it 'can be created with all fields' do
    report = VisitReport.create!(
      user_id: sw_user.id,
      client_id: client.id,
      appointment_id: appointment.id,
      date: '2026-05-01',
      activities: 'Assisted with bathing and medication',
      observations: 'Client was in good spirits',
      follow_up_actions: 'Book follow-up next week'
    )
    expect(report).to be_persisted
    expect(report.activities).to eq('Assisted with bathing and medication')
  end
end
