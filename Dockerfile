FROM ruby:3.3.4-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential libpq-dev nodejs git curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

RUN bundle exec rails assets:precompile RAILS_ENV=production SECRET_KEY_BASE=placeholder || true

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
