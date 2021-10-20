require_relative '../../util/spec_helper'

class ApiAcademicsRosterPage

  include PageObject
  include Logging

  def get_feed(driver, course)
    logger.info "Parsing data from /api/academics/rosters/canvas/#{course.site_id}"
    navigate_to "#{JunctionUtils.junction_base_url}/api/academics/rosters/canvas/#{course.site_id}"
    wait_until(Utils.medium_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  def sections
    @parsed['sections']
  end

  def section_names
    sections.map { |section| section['name'] }
  end

  def students
    @parsed['students']
  end

  def enrolled_students
    students.select { |student| student['enroll_status'] == 'E' }
  end

  def waitlisted_students
    students.select { |student| student['waitlist_position'] }
  end

  def section_students(section_name)
    students.select do |student|
      student_section_names = student['sections'].map { |section| section['name'] }
      student_section_names.include? section_name
    end
  end

  def student_last_names(students)
    names = students.map { |student| student['last_name'].downcase }
    names.sort
  end

  def all_student_uids
    (enrolled_students + waitlisted_students).map { |student| student['id'] }
  end

  def student_ids(students)
    students.map { |student| student['student_id'] }
  end

  def sid_from_uid(uid)
    begin
      student = students.find { |s| s['id'] == uid }
      student['student_id']
    rescue
      logger.warn "There is no UID #{uid} on the course SIS roster"
      nil
    end
  end

  def name_from_uid(uid)
    student = students.find { |s| s['id'] == uid }
    "#{student['first_name']} #{student['last_name']}"
  rescue
    logger.warn "There is no UID #{uid} on the course SIS roster"
  end

end
