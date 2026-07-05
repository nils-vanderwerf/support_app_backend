module WorkerApprovalGate
  extend ActiveSupport::Concern

  included do
    before_action :enforce_worker_approval
    class_attribute :skipped_worker_approval_actions, instance_writer: false, default: nil
  end

  class_methods do
    # Exempts this controller from the approved-support-worker gate. Call with no
    # args to exempt every action, or with action names to exempt just those —
    # for the rare cases where a pending/rejected worker legitimately needs access
    # (their own profile, the vetting flow, admin messaging, session lookup, etc).
    def skip_worker_approval_check(*actions)
      self.skipped_worker_approval_actions = actions.empty? ? :all : actions.map(&:to_sym)
    end
  end

  private

  # Shared before_action for support-worker-only endpoints — this is a role check
  # (are you a support worker at all?), separate from the approval-status check
  # below, so it still applies even on controllers that skip_worker_approval_check.
  def require_support_worker
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker
  end

  def enforce_worker_approval
    worker = current_user&.support_worker
    return if worker.nil? || worker.status == 'approved' || worker_approval_check_skipped?

    render json: { error: 'Your account is pending approval' }, status: :forbidden
  end

  def worker_approval_check_skipped?
    skipped = self.class.skipped_worker_approval_actions
    skipped == :all || skipped&.include?(action_name.to_sym)
  end
end
