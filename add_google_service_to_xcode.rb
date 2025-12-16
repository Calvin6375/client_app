#!/usr/bin/env ruby
# Script to add GoogleService-Info.plist to Xcode project
# Usage: ruby add_google_service_to_xcode.rb

require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner target
target = project.targets.find { |t| t.name == 'Runner' }
unless target
  puts "❌ Could not find Runner target"
  exit 1
end

# Find the Runner group
runner_group = project.main_group.find_subpath('Runner', true)
unless runner_group
  puts "❌ Could not find Runner group"
  exit 1
end

# Check if file already exists in project
file_path = 'ios/Runner/GoogleService-Info.plist'
file_ref = runner_group.files.find { |f| f.path == 'GoogleService-Info.plist' }

if file_ref
  puts "✅ GoogleService-Info.plist already exists in Xcode project"
else
  # Add the file reference
  file_ref = runner_group.new_file('GoogleService-Info.plist')
  puts "✅ Added GoogleService-Info.plist to Xcode project"
end

# Add to target's resources build phase if not already added
resources_phase = target.resources_build_phase
unless resources_phase.files_references.include?(file_ref)
  resources_phase.add_file_reference(file_ref)
  puts "✅ Added GoogleService-Info.plist to Resources build phase"
end

# Save the project
project.save
puts "✅ Xcode project updated successfully!"
puts ""
puts "Next steps:"
puts "1. Run: flutter clean"
puts "2. Run: cd ios && pod install && cd .."
puts "3. Run: flutter run"

