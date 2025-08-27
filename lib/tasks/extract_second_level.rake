# lib/tasks/extract_second_level.rake
namespace :cj do
  desc "Extract unique second-level categories from tmp/cj_categories.json"
  task extract_second_level: :environment do
    require "json"

    file_path = Rails.root.join("tmp", "cj_categories.json")

    unless File.exist?(file_path)
      puts "❌ File not found: #{file_path}"
      exit
    end

    json_data = JSON.parse(File.read(file_path))

    second_level_categories = json_data.flat_map do |first_level|
      first_level["categoryFirstList"]&.map { |second_level| second_level["categorySecondName"] }
    end.compact.uniq

    puts "✅ Found #{second_level_categories.size} unique second-level categories:"
    puts second_level_categories.sort

    output_file = Rails.root.join("tmp", "second_level_categories.json")
    File.write(output_file, JSON.pretty_generate(second_level_categories))

    puts "\n?? Saved to: #{output_file}"
  end
end
