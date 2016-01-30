class GetSalesforceBookNames

  lev_routine transaction: :no_transaction, express_output: :book_names

  def exec(force_cache_miss = false)
    unless force_cache_miss
      outputs[:book_names] = ActiveForce.cache_store.get('book_names')
      return unless outputs[:book_names].nil?
    end

    outputs[:book_names] = Salesforce::Remote::Book.all.map(&:name)
    ActiveForce.cache_store.set('book_names', outputs[:book_names])
  end

end
