# This migration comes from flancer (originally 20180503102148)
class ChangeFlancerFreelancerJobsColor < ActiveRecord::Migration[5.1]
  def change
    change_column :flancer_freelancer_jobs, :star_color, :string,null: true
  end
end
