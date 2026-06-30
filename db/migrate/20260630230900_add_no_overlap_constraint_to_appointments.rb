class AddNoOverlapConstraintToAppointments < ActiveRecord::Migration[7.1]
  def up
    return unless postgresql?

    enable_extension 'btree_gist'

    execute <<~SQL
      ALTER TABLE appointments
      ADD CONSTRAINT no_overlapping_appointments
      EXCLUDE USING gist (
        support_worker_id WITH =,
        tsrange(date, date + (COALESCE(duration, 60) * interval '1 minute'), '[)') WITH &&
      )
      WHERE (deleted_at IS NULL)
    SQL
  end

  def down
    return unless postgresql?

    execute "ALTER TABLE appointments DROP CONSTRAINT IF EXISTS no_overlapping_appointments"
    disable_extension 'btree_gist'
  end

  private

  def postgresql?
    connection.adapter_name.downcase.include?('postgresql')
  end
end
