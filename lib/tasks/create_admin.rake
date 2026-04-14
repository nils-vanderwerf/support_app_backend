namespace :admin do
  desc "Create admin user if one does not already exist"
  task create: :environment do
    User.find_or_create_by!(email: 'admin@example.com') do |u|
      u.password = 'password123'
      u.role = :admin
      u.first_name = 'Admin'
      u.last_name = 'User'
    end
    puts "Admin user ready."
  end
end
