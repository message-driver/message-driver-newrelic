source 'https://rubygems.org'

# Specify your gem's dependencies in message-driver-newrelic.gemspec
gemspec

gem 'message-driver', git: 'git@github.com/message-driver/message-driver', branch: 'development'

group "development" do
  gem "pry"
  gem "pry-byebug"
  gem "guard-rspec"
  install_if -> { RUBY_PLATFORM =~ /darwin/ } do
    gem "ruby_gntp"
  end
end
