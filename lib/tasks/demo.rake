desc 'Initializes data for the deployment demo (run all demo:* tasks), book can be either all, bio or phy.'
task :demo, [:book, :version, :random_seed] => :environment do |tt, args|
  failures = []
  Rake::Task[:"demo:content"].invoke(args[:book], args[:version], args[:random_seed]) \
    rescue failures << 'Content'
  Rake::Task[:"demo:tasks"].invoke(args[:book], args[:random_seed]) rescue failures << 'Tasks'
  unless ENV['NOWORK']
    Rake::Task[:"demo:work"].invoke(args[:book], args[:random_seed]) rescue failures << 'Work'
  end

  if failures.empty?
    puts 'All demo tasks successful!'
  else
    fail "Some demo tasks failed! (#{failures.join(', ')})"
  end
end

namespace :demo do

  desc 'Initializes book content for the deployment demo'
  task :content, [:book, :version, :random_seed] => :environment do |tt, args|
    require_relative 'demo/content'
    result = DemoContent.call(args.to_h.merge(print_logs: true))
    if result.errors.none?
      puts "Successfully imported content"
    else
      result.errors.each{ |error| puts "Content Error: " + Lev::ErrorTranslator.translate(error) }
      fail "Failed to import content"
    end
  end

  desc 'Creates assignments for students'
  task :tasks, [:book, :random_seed] => :environment do |tt, args|
    require_relative 'demo/tasks'
    result = DemoTasks.call(args.to_h.merge(print_logs: true))
    if result.errors.none?
      puts "Successfully created tasks"
    else
      result.errors.each{ |error| puts "Tasks Error: " + Lev::ErrorTranslator.translate(error) }
      fail "Failed to create tasks"
    end
  end

  desc 'Works student assignments'
  task :work, [:book, :random_seed] => :environment do |tt, args|
    require_relative 'demo/work'
    result = DemoWork.call(args.to_h.merge(print_logs: true))
    if result.errors.none?
      puts "Successfully worked tasks"
    else
      result.errors.each{ |error| puts "Tasks Error: " + Lev::ErrorTranslator.translate(error) }
      fail "Failed to work tasks"
    end
  end

  desc 'Output student assignments'
  task :show, [:book, :version, :random_seed] => :environment do |tt, args|
    require_relative 'demo/show'
    DemoShow.call(args.to_h.merge(print_logs: true))
  end
end
