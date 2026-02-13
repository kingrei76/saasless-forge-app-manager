module UsageSyncAdapters
  class Grok < Base
    # xAI doesn't have a usage API yet, so this adapter
    # is a no-op (usage is captured by the proxy).
    # Included as a reference implementation.
    def fetch_usage(since:, until_date: Time.current)
      [] # Proxy handles all Grok usage tracking
    end
  end
end
