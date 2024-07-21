class CreateJoinTableSupportWorkerSpecialization < ActiveRecord::Migration[7.1]
  def change
    create_join_table :support_workers, :specializations do |t|
      # t.index [:support_worker_id, :specialization_id]
      # t.index [:specialization_id, :support_worker_id]
    end
  end
end
