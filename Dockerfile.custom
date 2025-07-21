ARG RUBY_VERSION=3.3.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS assets
LABEL authors="Taylor Mravic <taylor.mravic@gmail.com>"

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl git libjemalloc2 libvips postgresql-client build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

ARG USER
ARG UID
ARG GID
ENV USER="${USER}" \
    UID="${UID}" \
    GID="${GID}"

RUN groupadd -g $GID $USER && \
    useradd -u $UID -g $USER -m $USER

RUN chown -R $USER:$USER /usr/local
RUN chown -R $USER:$USER /app

# Install Node.js v22.11.0 and Yarn using NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    ln -sf $(which node) /usr/local/bin/node && \
    ln -sf $(which npm) /usr/local/bin/npm && \
    ln -sf $(which yarn) /usr/local/bin/yarn

USER $USER

COPY --chown=$USER:$USER Gemfile* ./
RUN gem install rails
RUN bundle install

# Change working directory for npm and yarn
ENV NODE_PATH="/usr/local/node_modules"
ENV PATH="$NODE_PATH/.bin:$PATH"

COPY --chown=$USER:$USER package.json yarn.lock ./
RUN yarn install --modules-folder $NODE_PATH

ARG RAILS_ENV="development"
ARG NODE_ENV="development"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}"

# Move the entire build context into the image
COPY . .

RUN if [ "${RAILS_ENV}" != "development" ]; then \
    yarn build && SECRET_KEY_BASE_DUMMY=1 rails assets:precompile; fi

EXPOSE 3000

CMD ["bash"]

# Stage 2: App (runtime environment)
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS app
LABEL authors="Taylor Mravic <taylor.mravic@gmail.com>"

WORKDIR /app

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential vim libpq5 && \
    rm -rf /var/lib/apt/lists/*

ARG USER
ARG UID
ARG GID
ENV USER="${USER}" \
    UID="${UID}" \
    GID="${GID}"

RUN groupadd -g $GID $USER && \
    useradd -u $UID -g $USER -m $USER

RUN chown -R $USER:$USER /usr/local
RUN chown -R $USER:$USER /app

USER $USER

COPY --from=assets --chown=$USER:$USER /usr/local/bundle /usr/local/bundle
COPY --from=assets --chown=$USER:$USER /usr/local/node_modules /usr/local/node_modules
COPY --from=assets --chown=$USER:$USER /usr/bin /usr/bin
COPY --from=assets --chown=$USER:$USER /usr/lib/node_modules /usr/lib/node_modules
COPY --from=assets --chown=$USER:$USER /app /app

# Set environment variables for the runtime
ENV RAILS_ENV="development" \
    NODE_ENV="development"

# Expose the Rails server port
EXPOSE 3000

# Start the Rails server
CMD ["rails", "s", "-b", "0.0.0.0"]
FROM ubuntu:latest
LABEL authors="Taylor"

ENTRYPOINT ["top", "-b"]