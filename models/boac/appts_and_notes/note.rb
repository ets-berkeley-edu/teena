class Note < NoteTemplate

  attr_accessor :source_body_empty,
                :advisor

  def initialize(note_data)
    note_data.each { |k, v| public_send("#{k}=", v) }
    @topics ||= []
    @attachments ||= []
  end

end
