class UserRole < EnumerateIt::Base
  associate_values(:client, :support_worker, :user)
end