# Configure Active Job to use solid_queue for background job processing
# solid_queue is Rails 8's default queue adapter that uses the database for storage

Rails.application.config.active_job.queue_adapter = :solid_queue
