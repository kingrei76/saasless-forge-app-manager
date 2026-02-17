namespace :github do
  desc "Backfill github_owner from full_name for existing apps"
  task backfill_owner: :environment do
    updated = 0
    App.where(github_owner: nil).find_each do |app|
      next unless app.full_name.present?

      owner = app.full_name.split("/").first
      app.update_column(:github_owner, owner)
      updated += 1
    end
    puts "Backfilled github_owner for #{updated} apps."
  end

  desc "Remove apps not belonging to the target GitHub organization"
  task cleanup_non_org_apps: :environment do
    target_org = Setting[:github_target_organization]
    unless target_org.present?
      puts "ERROR: Setting[:github_target_organization] is not set. Set it first."
      exit 1
    end

    non_org_apps = App.where.not(github_owner: target_org)
                      .or(App.where(github_owner: nil))
    count = non_org_apps.count

    if count == 0
      puts "No non-org apps found. Nothing to clean up."
      exit 0
    end

    puts "Found #{count} apps outside '#{target_org}':"
    non_org_apps.order(:full_name).each do |app|
      puts "  - #{app.full_name || app.name} (owner: #{app.github_owner || 'nil'}, id: #{app.id})"
    end

    print "\nDelete these #{count} apps and all dependent records? [y/N] "
    confirm = $stdin.gets&.strip&.downcase
    unless confirm == "y"
      puts "Aborted."
      exit 0
    end

    non_org_apps.destroy_all
    puts "Deleted #{count} non-org apps."
  end
end
