class Status < ActiveRecord::Base
  validates_presence_of :user_id, :message
  
  concerned_with :hacky_date_methods
  
  attr_writer :followup
  
  belongs_to :user
  belongs_to :project

  has_finder :for_project, lambda { |project| { :conditions => {:project_id => project.id}, :extend => LatestExtension } }
  has_finder :without_project, :conditions => {:project_id => nil}, :extend => LatestExtension
  
  after_create :cache_user_status
#  before_update :calculate_hours
  
  acts_as_state_machine :initial => :pending
  state :pending, :enter => :process_previous
  state :processed
  
  event :process do
    transitions :from => :pending, :to => :processed, :guard => :calculate_hours
  end
  
  def self.with_user(user, &block)
    with_scope :find => { :conditions => ['statuses.user_id = ?', user.id] }, &block
  end
  
  def self.since(date, &block)
    with_scope :find => { :conditions => ['hours is not null and created_at >= ?', date.utc.midnight] }, &block
  end

  def followup(reload = false)
    @followup   = nil if reload
    @followup ||= user.statuses.after(self) || :false
    @followup == :false ? nil : @followup
  end
  
  def previous(reload = false)
    @previous   = nil if reload
    @previous ||= user.statuses.before(self) || :false
    @previous == :false ? nil : @previous
  end
  
  def project?
    !project_id.nil?
  end

  def editable_by?(user)
    user && user_id == user.id
  end
  
  def validate
    return validate_followup && validate_previous
  end
  
  def validate_followup
    return true if (user.nil? or followup.nil? or followup.followup.nil?)
    value = followup.followup_time
    if followup_time > value
      errors.add :followup_time, "Cannot extend this status to after the next status' end-point. Delete the next status." 
      return false
    else
      # errors.add :followup_time, "Cannot extend this status to after the next status' end-point. Delete the next status." 
      # n othing
      true
    end
  end
  
  def validate_previous
    return true if (user.nil? or previous.nil?)
    value = previous.created_at
    if value > created_at
      errors.add :created_at, "Cannot travel back in time with this status in hand."
      return false
    else
      # nothign
      true
    end
  end

protected
  def calculate_hours
    return false if followup.nil?
    quarters = (accurate_time.to_f / 15.minutes.to_f).ceil
    self.hours = quarters.to_f / 4.0
  end
  
  def process_previous
    previous.process! if previous(true) && previous.pending?
  end
  
  def cache_user_status
    User.update_all ['last_status_project_id = ?, last_status_id = ?, last_status_message = ?, last_status_at = ?', project_id, id, message, created_at], ['id = ?', user_id]
  end
end
