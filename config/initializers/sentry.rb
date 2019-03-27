sentry_dsn = Rails.configuration.sentry_dsn
if sentry_dsn
  Raven.configure do |config|
    config.dsn = sentry_dsn
    config.excluded_exceptions << 'JWT::ExpiredSignature'
  end
else
  Rails.logger.warn '[WARN] Sentry is not configured (SENTRY_DSN)'
end
