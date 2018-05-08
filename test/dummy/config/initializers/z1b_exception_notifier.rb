ActiveSupport::Notifications.subscribe('notify_exception') do |name, start, finish, id, payload|
  # do some stuff here

  puts "Dummy message has been received with some more extra #{payload[:options][:extra]}"
end