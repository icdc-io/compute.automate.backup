$evm.root['service'].backups.select { |b| b.status.include?("creat") }.each do |rb|
  rb.update_attributes(:status => "error", :error => true, :terminated => true)
end
