/// Retry / exponential-backoff configuration used by Providers.
class RetryConfig {
  RetryConfig._();

  static const int maxRetries = 3;
  static const int baseDelaySeconds = 2;
}
