source 'https://rubygems.org'

# Specify your gem's dependencies in message-driver-newrelic.gemspec
gemspec

platform :rbx do
  gem 'rubysl'
end

group "development" do
  gem "pry"
  gem "pry-byebug"
  gem "guard-rspec"
  install_if -> { RUBY_PLATFORM =~ /darwin/ } do
    gem "ruby_gntp"
  end
end
