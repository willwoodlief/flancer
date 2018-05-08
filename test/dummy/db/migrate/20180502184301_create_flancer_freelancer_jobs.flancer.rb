# This migration comes from flancer (originally 20180416042831)
class CreateFlancerFreelancerJobs < ActiveRecord::Migration[5.1]
  def change
    create_table :flancer_freelancer_jobs do |t|
      t.integer :internal_id,  null: false
      t.boolean :is_read, null:false, default:false
      t.integer :star_color, default: nil, null: true
      t.string :star_symbol, default: nil, null: true

      t.text :price_hint, default: nil, null: true
      t.text :number_bids, default: nil, null: true
      t.text :link, default: nil, null: true
      t.text :title, default: nil, null: true
      t.text :description, default: nil, null: true
      t.text :tags, default: nil, null: true
      t.text :status, default: nil, null: true
      t.text :when_posted, default: nil, null: true

      t.text :comments, default: nil, null: true

      t.timestamps
    end

    add_index :flancer_freelancer_jobs, [:internal_id],  :unique => true
    add_index :flancer_freelancer_jobs, [:is_read], :unique => false
  end
end
