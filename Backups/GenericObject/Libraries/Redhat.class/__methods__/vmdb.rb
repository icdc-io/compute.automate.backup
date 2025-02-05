#
# Description: vmdb lib that is used for backup
#

# In this part we try to get record about vm/snapshot/template from DB and if record doesn't exist - waiting while Refresher add it to DB
# 10 times and 10 second - random numbers :)
def get_vm_or_template_from_vmdb(uid_ems)
  get_object_from_vmdb(:VmOrTemplate, uid_ems: uid_ems)
end

def get_object_from_vmdb(object_class, search_param)
  record = $evm.vmdb(object_class).find_by(search_param)

  10.times do
    break if record

    sleep 10
    record = $evm.vmdb(object_class).find_by(search_param)
  end

  record
end
