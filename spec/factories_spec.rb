require 'rails_helper'

RSpec.describe 'Factories' do
  it 'builds a valid user' do
    expect(build(:user)).to be_valid
  end

  it 'builds a valid client' do
    expect(build(:client)).to be_valid
  end

  it 'builds a valid support_worker' do
    expect(build(:support_worker)).to be_valid
  end

  it 'builds a valid support_worker :pending' do
    expect(build(:support_worker, :pending)).to be_valid
  end

  it 'builds a valid support_worker :rejected' do
    expect(build(:support_worker, :rejected)).to be_valid
  end

  it 'builds a valid support_worker :with_credentials' do
    expect(build(:support_worker, :with_credentials)).to be_valid
  end

  it 'builds a valid specialisation' do
    expect(build(:specialisation)).to be_valid
  end

  it 'builds a valid appointment' do
    expect(build(:appointment)).to be_valid
  end

  it 'builds a valid appointment :pending' do
    expect(build(:appointment, :pending)).to be_valid
  end

  it 'builds a valid appointment :past' do
    expect(build(:appointment, :past)).to be_valid
  end

  it 'builds a valid conversation' do
    expect(build(:conversation)).to be_valid
  end

  it 'builds a valid message' do
    expect(build(:message)).to be_valid
  end

  it 'builds a valid message :from_support_worker' do
    expect(build(:message, :from_support_worker)).to be_valid
  end

  it 'creates a valid visit_report' do
    expect(create(:visit_report)).to be_valid
  end

  it 'creates a valid progress_report' do
    expect(create(:progress_report)).to be_valid
  end

  it 'creates a user with a unique email each time' do
    u1 = create(:user)
    u2 = create(:user)
    expect(u1.email).not_to eq(u2.email)
  end

  it 'creates a support_worker :with_specialisations with two specialisations' do
    worker = create(:support_worker, :with_specialisations)
    expect(worker.specialisations.count).to eq(2)
  end

  it 'derives visit_report support_worker_id and client_id from appointment' do
    vr = create(:visit_report)
    expect(vr.support_worker_id).to eq(vr.appointment.support_worker.id)
    expect(vr.client_id).to eq(vr.appointment.client_id)
  end

  it 'derives progress_report support_worker_id from worker transient' do
    pr = create(:progress_report)
    expect(pr.support_worker_id).to be_present
  end
end
