class OpenStax::Exercises::V1::Exercise

  attr_reader :content

  def initialize(content: '{}', server_url: OpenStax::Exercises::V1.server_url)
    @content = content
    @server_url = server_url
  end

  def content_hash
    return @content_hash unless @content_hash.nil?

    @content_hash = JSON.parse(content)
    stringify_content_hash_ids!
    @content_hash
  end

  def uid
    @uid ||= content_hash['uid']
  end

  def number
    @number ||= content_hash['number']
  end

  def version
    @version ||= content_hash['version']
  end

  def url
    @url ||= "#{@server_url}/exercises/#{uid}"
  end

  def title
    @title ||= content_hash['title']
  end

  def tags
    @tags ||= content_hash['tags']
  end

  def tag_hashes
    @tag_hashes ||= tags.collect do |tag|
      {
        value: tag,
        type: Tagger.get_type(tag)
      }
    end
  end

  def lo_hashes
    @lo_hashes ||= tag_hashes.select{ |hash| hash[:type] == :lo }
  end

  def aplo_hashes
    @aplo_hashes ||= tag_hashes.select{ |hash| hash[:type] == :aplo }
  end

  def cc_hashes
    @cc_hashes ||= tag_hashes.select{ |hash| hash[:type] == :cc }
  end

  def los
    @los ||= lo_hashes.collect{ |hash| hash[:value] }
  end

  def aplos
    @aplos ||= aplo_hashes.collect{ |hash| hash[:value] }
  end

  def ccs
    @ccs ||= cc_hashes.collect{ |hash| hash[:value] }
  end

  def questions
    @questions ||= content_hash['questions']
  end

  def question_formats
    @question_formats ||= questions.collect{ |qq| qq['formats'] }
  end

  def question_answers
    @question_answers ||= questions.collect{ |qq| qq['answers'] }
  end

  def question_answer_ids
    @question_answer_ids ||= question_answers.collect do |qa|
      qa.collect{ |ans| ans['id'] }
    end
  end

  def correct_question_answers
    @correct_question_answers ||= question_answers.collect do |qa|
      qa.select do |ans|
        (Float(ans['correctness']) rescue 0) >= 1
      end
    end
  end

  def correct_question_answer_ids
    @correct_question_answer_ids ||= correct_question_answers.collect do |cqa|
      cqa.collect{ |ans| ans['id'].to_s }
    end
  end

  def feedback_map
    return @feedback_map unless @feedback_map.nil?

    @feedback_map = {}
    question_answers.each do |qa|
      qa.each { |ans| @feedback_map[ans['id']] = ans['feedback_html'] }
    end
    @feedback_map
  end

  def question_answers_without_correctness
    @question_answers_without_correctness ||= question_answers.collect do |qa|
      qa.collect { |ans| ans.except('correctness', 'feedback_html') }
    end
  end

  def questions_without_correctness
    @questions_without_correctness ||= questions.each_with_index.collect do |qq, ii|
      qq.merge('answers' => question_answers_without_correctness[ii])
    end
  end

  def content_hash_without_correctness
    @content_hash_without_correctness ||= content_hash.merge(
      'questions' => questions_without_correctness
    )
  end

  def question_answers_with_stats(stats)
    question_answers.collect do |qa|
      qa.collect{ |ans| ans.merge('selected_count' => stats[ans['id']] || 0) }
    end
  end

  def questions_with_answer_stats(stats)
    answer_stats = question_answers_with_stats(stats)
    questions.each_with_index.collect do |qq, ii|
      qq.merge('answers' => answer_stats[ii])
    end
  end

  def content_with_answer_stats(stats)
    content_hash.merge('questions' => questions_with_answer_stats(stats))
  end

  protected

  def stringify_content_hash_ids!
    (@content_hash['authors'] || []).each do |au|
      au['user_id'] = au['user_id'].try(:to_s)
    end

    (@content_hash['copyright_holders'] || []).each do |cr|
      cr['user_id'] = cr['user_id'].try(:to_s)
    end

    (@content_hash['questions'] || []).each do |qq|
      qq['id'] = qq['id'].try(:to_s)
      (qq['answers'] || []).each do |aa|
        aa['id'] = aa['id'].try(:to_s)
      end
    end
  end

end
