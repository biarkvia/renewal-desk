FROM ruby:3.4.12-slim-bookworm@sha256:c81ac5a2118161a9e01cfbb2da6d68ae1c96d3e6dff14fb1f7f485fee538babe AS base

ENV BUNDLE_FROZEN=true \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR /rails

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 tzdata && \
    rm -rf /var/lib/apt/lists/*

FROM base AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install

FROM base

RUN groupadd --gid 1000 rails && \
    useradd --uid 1000 --gid rails --create-home rails

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails . .
RUN mkdir -p log tmp/pids && \
    chown -R rails:rails log tmp && \
    chmod +x bin/*

USER rails

EXPOSE 3000
