class ChangeExperienceToIntegerOnSupportWorkers < ActiveRecord::Migration[7.1]
  def up
    add_column :support_workers, :experience_years, :integer

    SupportWorker.find_each do |w|
      next unless w.experience.present?
      match = w.experience.to_s.match(/\d+/)
      w.update_column(:experience_years, match[0].to_i) if match
    end

    remove_column :support_workers, :experience
    rename_column :support_workers, :experience_years, :experience
  end

  def down
    add_column :support_workers, :experience_text, :text
    SupportWorker.find_each do |w|
      next unless w.experience.present?
      w.update_column(:experience_text, "#{w.experience} years")
    end
    remove_column :support_workers, :experience
    rename_column :support_workers, :experience_text, :experience
  end
end
