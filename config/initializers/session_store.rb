Rails.application.config.session_store :cookie_store,
  key: '_support_app_session',
  same_site: Rails.env.production? ? :none : :lax,
  secure: Rails.env.production?
