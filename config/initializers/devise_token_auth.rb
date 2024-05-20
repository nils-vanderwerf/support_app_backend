DeviseTokenAuth.setup do |config|
  # By default, users will need to re-authenticate after 2 weeks.
  # This setting determines how long tokens will remain valid after they are issued.
  config.token_lifespan = 2.weeks

  # Enables the batch request feature, which allows multiple requests to be made within the same second
  # and they will all share the same auth token. This is beneficial for performance reasons.
  config.batch_request_buffer_throttle = 5.seconds

  # If you're concerned about the security of your tokens, you can enable this feature.
  # It will change the auth token for each request. While this can increase security,
  # it might be a performance concern because it requires updating the user record on each request.
  config.change_headers_on_each_request = false

  # This configures which authentication headers should be used.
  # By default, the uid header is the user's email. You can change these headers to be
  # any other header that uniquely identifies the user.
  config.headers_names = {:'access-token' => 'access-token',
                          :'client' => 'client',
                          :'expiry' => 'expiry',
                          :'uid' => 'uid',
                          :'token-type' => 'token-type' }

  # This is the class that will be used to create users. You can change this
  # to any class that includes `Devise::Models::DatabaseAuthenticatable`.
  config.default_confirm_success_url = "http://example.com"

  # If you want to use another model (e.g., Admin) you can set it here.
  # config.parent_controller = 'DeviseTokenAuth::ApplicationController'
end