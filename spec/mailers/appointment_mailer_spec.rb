require 'rails_helper'

RSpec.describe AppointmentMailer, type: :mailer do
  let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
  let(:client) { Client.create!(user_id: client_user.id, first_name: 'Jane', last_name: 'Doe', email: 'client@test.com') }
  let(:support_worker_user) { User.create!(email: 'worker@test.com', first_name: 'Bob', last_name: 'Brown', password: 'password123', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user_id: support_worker_user.id, email: 'worker@test.com', first_name: 'Bob', last_name: 'Brown', phone: '0400000000', age: 30, location: 'Sydney') }
  let(:appointment) do
    Appointment.create!(
      client: client,
      support_worker: support_worker,
      date: 2.days.from_now,
      duration: 60,
      location: 'Sydney CBD',
      notes: 'Bring medication list'
    )
  end

  describe '#reminder_to_client' do
    let(:mail) { AppointmentMailer.reminder_to_client(appointment) }

    it 'sends to the client email' do
      expect(mail.to).to eq([client_user.email])
    end

    it 'includes the support worker name in the subject' do
      expect(mail.subject).to include('Bob Brown')
    end

    it 'includes the support worker name in the body' do
      expect(mail.body.encoded).to include('Bob')
    end

    it 'greets the client by first name' do
      expect(mail.body.encoded).to include('Jane')
    end

    it 'includes location in the body' do
      expect(mail.body.encoded).to include('Sydney CBD')
    end

    it 'includes notes when present' do
      expect(mail.body.encoded).to include('Bring medication list')
    end
  end

  describe '#reminder_to_support_worker' do
    let(:mail) { AppointmentMailer.reminder_to_support_worker(appointment) }

    it 'sends to the support worker email' do
      expect(mail.to).to eq(['worker@test.com'])
    end

    it 'includes the client name in the subject' do
      expect(mail.subject).to include('Jane Doe')
    end

    it 'includes the client name in the body' do
      expect(mail.body.encoded).to include('Jane')
    end

    it 'greets the support worker by first name' do
      expect(mail.body.encoded).to include('Bob')
    end

    it 'includes location in the body' do
      expect(mail.body.encoded).to include('Sydney CBD')
    end

    it 'includes notes when present' do
      expect(mail.body.encoded).to include('Bring medication list')
    end
  end
end
