#
# Description: Backup and Restore constants for comfort
#

Backup  = $evm.vmdb(:GenericObjectDefinition).find_by(name: 'Backup')
Restore = $evm.vmdb(:GenericObjectDefinition).find_by(name: 'Restore')
