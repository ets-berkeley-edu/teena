require_relative 'spec_helper'

class NessieUtils < Utils

  @config = Utils.config['nessie']

  def self.nessie_redshift_db_credentials
    {
      :host => @config['redshift_db_host'],
      :port => @config['redshift_db_port'],
      :name => @config['redshift_db_name'],
      :user => @config['redshift_db_user'],
      :password => @config['redshift_db_password']
    }
  end

  def self.nessie_pg_db_credentials
    {
      :host => @config['pg_db_host'],
      :port => @config['pg_db_port'],
      :name => @config['pg_db_name'],
      :user => @config['pg_db_user'],
      :password => @config['pg_db_password']
    }
  end

  # The number of hours that synced Canvas data is behind actual site usage data
  def self.canvas_data_lag_hours
    @config['canvas_data_lag_hours']
  end

  # Whether or not to test Caliper last activity data
  def self.include_caliper_tests
    @config['include_caliper_tests']
  end

  # The number of seconds that is the max acceptable diff between last activity shown in Canvas vs Caliper
  def self.caliper_time_margin
    @config['caliper_time_margin']
  end

  # Whether or not to include L&S students and advisors
  def self.include_l_and_s?
    @config['include_l_and_s']
  end

  #### ASSIGNMENTS ####

  # Returns the assignments associated with a user in a course site
  # @param user [User]
  # @param course [Course]
  # @return [Array<Assignment>]
  def self.get_assignments(user, course)
    query = "SELECT assignment_id, due_at, submitted_at, assignment_status
              FROM boac_analytics.assignment_submissions_scores
              WHERE course_id = #{course.site_id}
                AND canvas_user_id = #{user.canvas_id}
              ORDER BY assignment_id;"
    results = query_redshift_db(nessie_redshift_db_credentials, query)
    results.map do |r|
      submitted = %w(on_time late submitted graded).include? r['assignment_status']
      Assignment.new({:id => r['assignment_id'], :due_date => r['due_at'], :submission_date => r['submitted_at'], :submitted => submitted})
    end
  end

  # Returns the Caliper last activity metric for a user in a course site
  # @param user [BOACUser]
  # @param site_id [String]
  # @return [Time]
  def self.get_caliper_last_activity(user, site_id)
    query = "SELECT last_activity
              FROM lrs_caliper_analytics.last_activity_caliper
              WHERE canvas_course_id = #{site_id}
                AND canvas_user_id = #{user.canvas_id};"
    results = query_redshift_db(nessie_redshift_db_credentials, query)
    activities = results.map { |r| Time.parse(r['last_activity'][0..18] += ' UTC') }
    activities.max
  end

  #### ALL STUDENTS ####

  # Returns an array of students who have current academic status
  # @return [Array<BOACUser>]
  def self.get_all_students
    query = 'SELECT student_academic_status.uid AS uid,
                    student_academic_status.sid AS sid,
                    student_academic_status.first_name AS first_name,
                    student_academic_status.last_name AS last_name
             FROM student.student_academic_status
             ORDER BY uid;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)

    results.map do |r|
      attributes = {
        :uid => r['uid'],
        :sis_id => r['sid'],
        :first_name => r['first_name'],
        :last_name => r['last_name'],
        :full_name => "#{r['first_name']} #{r['last_name']}"
      }
      BOACUser.new attributes
    end
  end

  #### ASC ####

  # Returns all the distinct teams associated with team members
  # @return [Array<Team>]
  def self.get_asc_teams
    # Get the squads associated with ASC students
    query = 'SELECT DISTINCT group_code
              FROM boac_advising_asc.students;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results = results.map { |r| r['group_code'] }
    squads = Squad::SQUADS.select { |squad| results.include? squad.code }
    squads.sort_by { |s| s.name }

    # Get the teams associated with the squads
    teams = squads.map &:parent_team
    teams.uniq!
    logger.info "Teams are #{teams.map &:name}"
    teams.sort_by { |t| t.name }
  end

  #### CoE ####

  # Returns all the CoE students associated with a given advisor
  # @param advisor [User]
  # @param all_coe_students [Array<User>]
  # @return [Array<User>]
  def self.get_coe_advisor_students(advisor, all_coe_students)
    query = "SELECT students.sid
              FROM boac_advising_coe.students
              WHERE students.advisor_ldap_uid = '#{advisor.uid}'
              ORDER BY students.sid;"
    result = Utils.query_pg_db(nessie_pg_db_credentials, query)
    result = result.map { |r| r['sid'] }
    all_coe_students.select { |s| result.include? s.sis_id }
  end

  #### HISTORICAL STUDENTS ####

  # Returns the number of non-current students with a given academic career status
  # @param status [String]
  # @return [Integer]
  def self.hist_career_status_count(status)
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": \"#{status}\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with academic career status '#{status}' is #{result}"
    result
  end

  # Returns the number of non-current students with a null academic career status
  # @return [Integer]
  def self.null_hist_career_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile NOT LIKE '%\"academicCareerStatus\": %';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with NULL academic career status is #{result}"
    result
  end

  # Returns the number of non-current students with an unexpected academic career status
  # @return [Integer]
  def self.unexpected_hist_career_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": %'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Active\"%'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Inactive\"%'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Completed\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with unexpected academic career status is #{result}"
    result
  end

  # Returns the number of non-current students with a given program status
  # @param status [String]
  # @return [Integer]
  def self.hist_prog_status_count(status)
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"status\": \"#{status}\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with academic program status '#{status}' is #{result}"
    result
  end

  # Returns the number of non-current students with an unexpected program status
  # @return [Integer]
  def self.unexpected_hist_prog_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"status\": %'
               AND profile NOT LIKE '%\"status\": \"Active\"%'
               AND profile NOT LIKE '%\"status\": \"Cancelled\"%'
               AND profile NOT LIKE '%\"status\": \"Completed Program\"%'
               AND profile NOT LIKE '%\"status\": \"Deceased\"%'
               AND profile NOT LIKE '%\"status\": \"Discontinued\"%'
               AND profile NOT LIKE '%\"status\": \"Dismissed\"%'
               AND profile NOT LIKE '%\"status\": \"Suspended\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with unexpected academic program status is #{result}"
    result
  end

  # Returns the SIDs of non-current students in the profiles table
  # @return [Array<String>]
  def self.hist_profile_sids
    query = 'SELECT sid
             FROM student.student_profiles_hist_enr
             ORDER BY sid ASC;'
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students with a given academic career status
  # @param status [String]
  # @return [Array<String>]
  def self.hist_profile_sids_of_career_status(status)
    query = "SELECT sid
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": \"#{status}\"%';"
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students with null academic career status
  # @return [Array<String>]
  def self.null_hist_career_status_sids
    query = "SELECT sid
             FROM student.student_profiles_hist_enr
             WHERE profile NOT LIKE '%\"academicCareerStatus\": %';"
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students in the enrollments table
  # @return [Array<String>]
  def self.hist_enrollment_sids
    query = 'SELECT DISTINCT sid
             FROM student.student_enrollment_terms_hist_enr
             ORDER BY sid ASC;'
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns a non-current student with a given SID
  # @param sid [String]
  # @return [BOACUser]
  def self.get_hist_student(sid)
    query = "SELECT uid
             FROM student.student_profiles_hist_enr
             WHERE sid = '#{sid}';"
    uid = query_pg_db_field(nessie_pg_db_credentials, query, 'uid').last
    BOACUser.new(sis_id: sid, uid: uid)
  end

  #### SEARCHABLE STUDENT DATA ####

  # Parses a file containing searchable user data if it exists
  # @return [Array<Hash>]
  def self.parse_stored_searchable_data
    users_data_file = BOACUtils.searchable_data
    JSON.parse(File.read(users_data_file), {:symbolize_names => true}) if File.exist? users_data_file
  end

  # To support cohort search tests, returns all relevant user data for a given set of students, writing it to a file for
  # subsequent test runs.
  # @param users [Array<BOACUser>]
  # @return [Array<Hash>]
  def self.get_and_store_searchable_data(users)
    logger.warn 'Cannot find a searchable user data file created today, collecting data and writing it to a file for reuse today'

    # Delete older searchable data files before writing the new one
    Dir.glob("#{Utils.config_dir}/boac-searchable-data*").each { |f| File.delete f }

    # Get student data that is not already associated with the users. This will probably return more students than those present
    # in the combined CoE and ASC students tables.
    query = "SELECT student_academic_status.uid AS uid,
                    student_academic_status.sid AS sid,
                    student_academic_status.first_name AS first_name,
                    student_academic_status.last_name AS last_name,
                    student.student_profiles.profile AS profile,
                    student.student_academic_status.gpa AS gpa,
                    student.student_academic_status.level AS level_code,
                    student.student_majors.major AS majors,
                    student.student_enrollment_terms.midpoint_deficient_grade AS mid_point_deficient,
                    (ARRAY_AGG (boac_advising_asc.students.group_code || ',' || boac_advising_asc.students.active))
                      AS group_codes_with_status,
                    boac_advising_asc.students.intensive AS intensive_asc,
                    boac_advising_coe.students.advisor_ldap_uid AS advisor,
                    boac_advising_coe.students.gender AS coe_gender,
                    boac_advising_coe.students.ethnicity AS coe_ethnicity,
                    boac_advising_coe.students.minority AS minority,
                    boac_advising_coe.students.did_prep AS prep,
                    boac_advising_coe.students.prep_eligible AS prep_elig,
                    boac_advising_coe.students.did_tprep AS t_prep,
                    boac_advising_coe.students.tprep_eligible AS t_prep_elig,
                    boac_advising_coe.students.probation AS probation,
                    boac_advising_coe.students.status AS status_coe,
                    boac_advisor.advisor_students.advisor_sid AS advisor_sid,
                    boac_advisor.advisor_students.academic_plan_code AS advisor_plan_code
             FROM student.student_academic_status
             LEFT JOIN student.student_profiles
               ON student.student_academic_status.sid = student.student_profiles.sid
             LEFT JOIN student.student_majors
               ON student.student_academic_status.sid = student.student_majors.sid
             LEFT JOIN boac_advising_asc.students
               ON student.student_academic_status.sid = boac_advising_asc.students.sid
             LEFT JOIN boac_advising_coe.students
               ON student.student_academic_status.sid = boac_advising_coe.students.sid
             LEFT JOIN boac_advisor.advisor_students
               ON student.student_academic_status.sid = boac_advisor.advisor_students.student_sid
             LEFT JOIN student.student_enrollment_terms
               ON student.student_academic_status.sid = student.student_enrollment_terms.sid
                 AND student.student_enrollment_terms.term_id = '#{BOACUtils.term_code}'
             GROUP BY student_academic_status.uid, student_academic_status.sid, student_academic_status.first_name,
                      student_academic_status.last_name, student.student_profiles.profile, student.student_academic_status.gpa,
                      student.student_academic_status.level, student.student_majors.major, student.student_enrollment_terms.midpoint_deficient_grade,
                      boac_advising_asc.students.intensive, boac_advising_coe.students.advisor_ldap_uid, boac_advising_coe.students.gender,
                      boac_advising_coe.students.ethnicity, boac_advising_coe.students.minority, boac_advising_coe.students.did_prep,
                      boac_advising_coe.students.prep_eligible, boac_advising_coe.students.did_tprep, boac_advising_coe.students.tprep_eligible,
                      boac_advising_coe.students.probation, boac_advising_coe.students.status, boac_advisor.advisor_students.advisor_sid,
                      boac_advisor.advisor_students.academic_plan_code
             ORDER BY sid;"

    results = query_pg_db(nessie_pg_db_credentials, query)

    # Create a hash for each student in the results
    student_hashes = {}
    results.group_by { |h1| h1['sid'] }.each do |k,v|
      logger.debug "Getting data for SID #{k}"
      level = case (code = v[0]['level_code'])
                when '10'
                  'Freshman'
                when '20'
                  'Sophomore'
                when '30'
                  'Junior'
                when '40'
                  'Senior'
                when 'GR'
                  'Graduate'
                else
                  logger.error "Unknown level code '#{code}'"
                  nil
              end
      profile = JSON.parse(v[0]['profile'])
      sis_profile = profile['sisProfile']
      expected_grad = sis_profile && sis_profile['expectedGraduationTerm']
      cumulative_units = sis_profile && sis_profile['cumulativeUnits']
      demographics = profile && profile['demographics']

      # Determine if the student is ASC active in any sport
      group_codes_with_status = v[0]['group_codes_with_status'] && v[0]['group_codes_with_status'].delete("{}").split("\"").reject(&:empty?)
      asc_active = (group_codes_with_status && (group_codes_with_status.reject { |c| c.split(',')[1] == 'false' }).any?)

      # Get the squad names to use as search criteria if the students are athletes
      group_codes = (group_codes_with_status && (group_codes_with_status.map { |c| c.split(',').first }).join(' '))
      squad_codes = (group_codes ? group_codes.split.uniq : [])
      squad_names = squad_codes.map do |squad_code|
        squad = Squad::SQUADS.find { |s| s.code == squad_code }
        squad.name if squad
      end
      squad_names.compact!

      student_hashes[k] = {
        :sid => k,
        :entering_term => (sis_profile && sis_profile['matriculation'] && Utils.term_name_to_sis_code(sis_profile['matriculation'])),
        :ethnicity => (demographics && demographics['ethnicities']),
        :expected_grad_term => (expected_grad && expected_grad['id'].to_s),
        :gender => (demographics && demographics['gender']),
        :gpa => v[0]['gpa'],
        :level => level,
        :major => (v.map { |h| h['majors'] }).uniq.compact,
        :mid_point_deficient => (v[0]['mid_point_deficient'] == 't'),
        :transfer_student => (sis_profile && sis_profile['transfer']),
        :underrepresented_minority => (demographics && demographics['underrepresented']),
        :units_completed => cumulative_units,
        :asc_active => asc_active,
        :asc_intensive => (v[0]['intensive_asc'] == 't'),
        :asc_sports => squad_names,
        :coe_advisor => v[0]['advisor'],
        :coe_ethnicity => v[0]['coe_ethnicity'],
        :coe_gender => v[0]['coe_gender'],
        :coe_inactive => %w(D P U W X Z).include?(v[0]['status_coe']),
        :coe_prep => (v[0]['prep'] == 't'),
        :coe_probation => (v[0]['probation'] == 't'),
        :coe_underrepresented_minority => (v[0]['minority'] == 't'),
        :prep_elig => (v[0]['prep_elig'] == 't'),
        :t_prep => (v[0]['t_prep'] == 't'),
        :t_prep_elig => (v[0]['t_prep_elig'] == 't'),
        :advisors => (v.map { |h| {sid: h['advisor_sid'], plan_code: h['advisor_plan_code']}}).uniq.compact
      }
    end

    # Find the student hash associated with each CoE and ASC user and combine it with the data already known about the user.
    filtered_student_hashes = users.map do |user|
      logger.debug "Completing data for SID #{user.sis_id}"

      user_hash = student_hashes[user.sis_id]

      addl_user_data = {
        :first_name => user.first_name,
        :first_name_sortable_cohort => (user.first_name.split(' ').map { |s| s.gsub(/\W/, '').downcase }).join,
        :first_name_sortable_user_list => (user.first_name.split(' ').map { |s| s.gsub(/\W/, '').downcase }).join(' '),
        :last_name => user.last_name,
        :last_name_sortable_cohort => user.last_name.empty? ? ' ' : (user.last_name.split(' ').map { |s| s.gsub(/\W/, '').downcase }).join,
        :last_name_sortable_user_list => user.last_name.empty? ? ' ' : (user.last_name.split(' ').map { |s| s.gsub(/\W/, '').downcase }).join(' ')
      }
      user_hash.merge! addl_user_data if user_hash
      user_hash
    end

    # Write the data to a file for reuse.
    filtered_student_hashes.compact!
    File.open(BOACUtils.searchable_data, 'w') { |f| f.write filtered_student_hashes.to_json }
    filtered_student_hashes
  end

  # If a current file containing student search data exists, parse and return it. Otherwise, obtain the data, write it to a
  # file and return it
  # @param students [Array<BOACUser>]
  # @return [Array<Hash>]
  def self.searchable_student_data(students)
    (data = parse_stored_searchable_data) ? data : get_and_store_searchable_data(students)
  end

  # Get all academic plans associated with a given advisor and current students
  # @param advisor [User]
  # @return [Array<String>]
  def self.get_academic_plans(advisor)
    query = "SELECT DISTINCT boac_advisor.advisor_students.academic_plan_code AS plan_code
              FROM boac_advisor.advisor_students
              JOIN boac_advising_notes.advising_note_authors
                ON boac_advising_notes.advising_note_authors.uid = '#{advisor.uid}'
                AND boac_advising_notes.advising_note_authors.sid = boac_advisor.advisor_students.advisor_sid
              JOIN student.student_profiles
              ON student.student_profiles.sid = boac_advisor.advisor_students.student_sid
              ORDER BY boac_advisor.advisor_students.academic_plan_code;"
    Utils.query_pg_db(nessie_pg_db_credentials, query).map { |r| r['plan_code'] }
  end

  # Get a mapping of academic plan codes to human-readable descriptions
  # @return [Hash]
  def self.get_academic_plan_codes
    plan_map = {'*': 'All plans'}
    query = "SELECT DISTINCT academic_plan_code, academic_plan FROM boac_advisor.advisor_students"
    Utils.query_pg_db(nessie_pg_db_credentials, query).each do |r|
      plan_map[r['academic_plan_code']] = r['academic_plan']
    end
    plan_map
  end

  #### NOTES ####

  # Returns non-BOA advising notes from a given source for a given student
  # @param [String] schema
  # @param [BOACUser] student
  # @return[Array<Note>]
  def self.get_external_notes(schema, student)
    query = "SELECT #{schema}.advising_notes.id AS id,
                    #{schema}.advising_notes.advisor_uid AS advisor_uid,
                    #{schema}.advising_notes.advisor_first_name AS advisor_first_name,
                    #{schema}.advising_notes.advisor_last_name AS advisor_last_name,
                    #{schema}.advising_notes.created_at AS created_date,
                    #{schema}.advising_notes.updated_at AS updated_date,
                    #{schema}.advising_note_topics.topic AS topic
             FROM #{schema}.advising_notes
             LEFT JOIN #{schema}.advising_note_topics
               ON #{schema}.advising_notes.id = #{schema}.advising_note_topics.id
             WHERE #{schema}.advising_notes.sid = '#{student.sis_id}';"

    results = query_pg_db(nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      unless v[0]['advisor_first_name'] == 'Reception' && v[0]['advisor_last_name'] == 'Front Desk'
        {
            :id => k,
            :advisor => BOACUser.new({:uid => v[0]['advisor_uid'], :first_name => "#{v[0]['advisor_first_name']}", :last_name => "#{v[0]['advisor_last_name']}"}),
            :created_date => Time.parse(v[0]['created_date'].to_s).utc.localtime,
            :updated_date => Time.parse(v[0]['updated_date'].to_s).utc.localtime,
            :topics => (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort
        }
      end
    end

    notes_data.compact.map { |d| Note.new d }
  end

  # Returns ASC advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_asc_notes(student)
    get_external_notes('boac_advising_asc', student)
  end

  # Returns E&I advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_e_and_i_notes(student)
    get_external_notes('boac_advising_e_i', student)
  end

  # Returns SIS advising notes associated with a given student
  # @param student [BOACUser]
  # @return [Array<Note>]
  def self.get_sis_notes(student)
    query = "SELECT sis_advising_notes.advising_notes.id AS id,
                    sis_advising_notes.advising_notes.note_category AS category,
                    sis_advising_notes.advising_notes.note_subcategory AS subcategory,
                    sis_advising_notes.advising_notes.note_body AS body,
                    sis_advising_notes.advising_notes.created_by AS advisor_uid,
                    sis_advising_notes.advising_notes.advisor_sid AS advisor_sid,
                    sis_advising_notes.advising_notes.created_at AS created_date,
                    sis_advising_notes.advising_notes.updated_at AS updated_date,
                    sis_advising_notes.advising_note_topics.note_topic AS topic,
                    sis_advising_notes.advising_note_attachments.sis_file_name AS sis_file_name,
                    sis_advising_notes.advising_note_attachments.user_file_name AS user_file_name
            FROM sis_advising_notes.advising_notes
            LEFT JOIN sis_advising_notes.advising_note_topics
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_topics.advising_note_id
            LEFT JOIN sis_advising_notes.advising_note_attachments
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_attachments.advising_note_id
            WHERE sis_advising_notes.advising_notes.sid = '#{student.sis_id}';"

    results = query_pg_db(nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      # If the note has no body, concatenate the category and subcategory as the body
      source_body_empty = (v[0]['body'].nil? || v[0]['body'].strip.empty?)
      body = source_body_empty ?
                "#{v[0]['category']}#{+', ' if v[0]['subcategory']}#{v[0]['subcategory']}" :
                v[0]['body'].gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, ' ').gsub('&Tab;', ' ').gsub("\n", ' ').gsub('amp;', '').gsub('&nbsp;', ' ')

      attachment_data = v.map do |r|
        unless r['sis_file_name'].nil? || r['sis_file_name'].empty?
          {
            :sis_file_name => r['sis_file_name'],
            :file_name => ((r['advisor_uid'] == 'UCBCONVERSION') ? r['sis_file_name'] : r['user_file_name'])
          }
        end
      end
      attachments = attachment_data.compact.uniq.map { |d| Attachment.new d }

      advisor_uid = v[0]['advisor_uid']
      created_date = v[0]['created_date']
      updated_date = (advisor_uid == 'UCBCONVERSION') ? created_date : v[0]['updated_date']
      {
        :id => k,
        :body => body,
        :source_body_empty => source_body_empty,
        :advisor => BOACUser.new({:uid => advisor_uid}),
        :created_date => Time.parse(created_date.to_s).utc.localtime,
        :updated_date => Time.parse(updated_date.to_s).utc.localtime,
        :topics => (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
        :attachments => attachments
      }
    end
    notes_data.map { |d| Note.new d }
  end

  # Returns all SIS note authors
  # @param student [BOACUser]
  # @return [Array]
  def self.get_all_advising_note_authors
    query = "SELECT uid, sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map do |r|
      {
        :uid => r['uid'],
        :sid => r['sid'],
        :first_name => r['first_name'],
        :last_name => r['last_name']
      }
    end
  end

  # Returns basic identifying data for a SIS note author
  # @param uid [Fixnum]
  # @return [Array]
  def self.get_advising_note_author(uid)
    query = "SELECT sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors
              WHERE uid = '#{uid}';"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    if results.any?
      {
        :sid => results[0]['sid'],
        :first_name => results[0]['first_name'],
        :last_name => results[0]['last_name']
      }
    end
  end

  #### HOLDS ####

  # Returns a student's current holds
  # @param student [BOACUser]
  # @return [Array<Alert>]
  def self.get_student_holds(student)
    query = "SELECT sid, feed
              FROM student.student_holds
              WHERE sid = '#{student.sis_id}';"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map do |r|
      feed = JSON.parse r['feed']
      alert_data = {
        :message => "#{feed['reason']['description']}. #{feed['reason']['formalDescription']}".gsub("\n", '').gsub("\\u200b", '').gsub(/\s+/, ' '),
        :user => student
      }
      Alert.new alert_data
    end
  end

end
