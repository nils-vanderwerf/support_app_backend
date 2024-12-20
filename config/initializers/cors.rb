Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3001'  # Adjust the origin as per your React app's URL
    resource '*', headers: :any, methods: [:get, :post, :patch, :put, :delete, :options, :head], credentials: true
  end
end
