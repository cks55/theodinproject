class Lesson < ApplicationRecord
  extend FriendlyId

  friendly_id :slug_candidates, use: [:slugged, :finders]

  belongs_to :section
  has_one :course, through: :section
  has_one :project
  has_many :lesson_completions, dependent: :destroy
  has_many :completing_users, through: :lesson_completions, source: :student

  validates :position, uniqueness: true
  validates :content, presence: true, on: :update

  def self.projects_without_submissions
    [
      'Installations',
      'Practicing Git Basics',
      'Building Your Resume'
    ]
  end

  def type
    is_project? ? 'Project' : 'Lesson'
  end

  def next_lesson
    find_lesson.next_lesson
  end

  def prev_lesson
    find_lesson.prev_lesson
  end

  def position_in_section
    section_lessons.where('position <= ?', position).count
  end

  def import_content_from_github
    update(content: decoded_content) if content_needs_updated
  rescue Octokit::Error => errors
    failed_to_import_message
  end

  def has_submission?
    is_project? &&
    accepts_submission? &&
    is_not_a_ruby_project? # should be removed after revamping ruby lessons
  end

  def has_live_preview?
    has_submission? && is_not_a_ruby_project?
  end

  private

  def content_needs_updated
    content != decoded_content
  end

  def decoded_content
    @decoded_content ||= Base64.decode64(github_response[:content])
  end

  def github_response
    Octokit.contents('theodinproject/curriculum', path: url)
  end

  def failed_to_import_message
    logger.error "Failed to import \"#{title}\" content: #{errors}"
    false
  end

  def section_lessons
    section.lessons
  end

  def find_lesson
    FindLesson.new(self)
  end

  def slug_candidates
    [
      :title,
      [:title, course_title]
    ]
  end

  def course_title
    course&.title
  end

  def accepts_submission?
    !Lesson.projects_without_submissions.include?(title)
  end

  def is_not_a_ruby_project?
    title !=  'Ruby' && course_title != 'Ruby Programming'
  end
end
