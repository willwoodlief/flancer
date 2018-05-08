# This migration comes from flancer (originally 20180428005948)
class AddFlancerFreelancerJobsUniqueLink < ActiveRecord::Migration[5.1]
  def change
    change_column :flancer_freelancer_jobs, :internal_id, :integer,null: true
    change_column :flancer_freelancer_jobs, :link, :text,null: false,after: :star_color
    add_index :flancer_freelancer_jobs, [:link],  :unique => true, :length => 210
  end
end
