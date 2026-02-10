class Admin::BillingController < Admin::BaseController
  before_action :require_admin!

  def generate_monthly
    results = MonthlyInfrastructureBillingService.generate_for_all_clients

    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    if error_count == 0
      redirect_to admin_invoices_path, notice: "Generated #{success_count} infrastructure invoice(s)."
    else
      redirect_to admin_invoices_path, alert: "Generated #{success_count} invoice(s), #{error_count} failed."
    end
  end

  def generate_recurring_drafts
    results = MonthlyInfrastructureBillingService.generate_for_all_clients

    if results.empty?
      redirect_to admin_recurring_invoices_path, notice: "No clients with app assignments found."
      return
    end

    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    if success_count == 0 && error_count > 0
      errors = results.select { |r| !r[:success] }.map { |r| "#{r[:client]&.name}: #{r[:error]}" }.join("; ")
      redirect_to admin_invoices_path, alert: "No drafts generated. #{errors}"
    elsif error_count == 0
      redirect_to admin_invoices_path, notice: "Generated #{success_count} draft invoice(s) for review."
    else
      errors = results.select { |r| !r[:success] }.map { |r| "#{r[:client]&.name}: #{r[:error]}" }.join("; ")
      redirect_to admin_invoices_path, alert: "#{success_count} drafts generated, #{error_count} skipped. #{errors}"
    end
  end

  def process_recurring
    results = RecurringBillingService.process_all_due

    if results.empty?
      redirect_to admin_recurring_invoices_path, notice: "No recurring invoices are due today."
      return
    end

    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    if error_count == 0
      redirect_to admin_recurring_invoices_path, notice: "Processed #{success_count} recurring invoice(s) successfully."
    else
      errors = results.select { |r| !r[:success] }.map { |r| "#{r[:client]&.name}: #{r[:error]}" }.join("; ")
      redirect_to admin_recurring_invoices_path, alert: "#{success_count} succeeded, #{error_count} failed. Errors: #{errors}"
    end
  end
end
