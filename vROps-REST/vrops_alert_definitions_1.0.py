# Import modules
import requests
import xml.etree.ElementTree as ElementTree
from requests.auth import HTTPBasicAuth
import urllib3
urllib3.disable_warnings()

# Define name spaces
ns = {'vrops': 'http://webservice.vmware.com/vRealizeOpsMgr/1.0/'}

# Retrieve adapters
akUrl = 'https://your-vrops-hostname/suite-api/api/adapterkinds'
adapterKinds = requests.get(akUrl, verify=False, auth=HTTPBasicAuth('username', 'password'))
akRoot = ElementTree.fromstring(adapterKinds.content)
for akItem in akRoot.iterfind('vrops:adapter-kind', ns):
	akId = akItem.attrib['key']
	akNameItem = akItem.find('vrops:name', ns)
	akName = akNameItem.text

	# Retrieve object types
	rkUrl = 'https://your-vrops-hostname/suite-api/api/adapterkinds' + '/' + akId + '/resourcekinds'
	resourceKinds = requests.get(rkUrl, verify=False, auth=HTTPBasicAuth('username', 'password'))
	rkRoot = ElementTree.fromstring(resourceKinds.content)	
	for rkItem in rkRoot.iterfind('vrops:resource-kind', ns):
		rkNameItem = rkItem.find('vrops:name', ns)
		rkName = rkNameItem.text
		rkId = rkItem.attrib['key']

		# Retrieve alert definitions
		adUrl = 'https://your-vrops-hostname/suite-api/api/alertdefinitions' + '?resourceKind=' + rkId
		alertDefinitions = requests.get(adUrl, verify=False, auth=HTTPBasicAuth('username', 'password'))
		adRoot = ElementTree.fromstring(alertDefinitions.content)
		for adItem in adRoot.iterfind('vrops:alert-definition', ns):

			# Determine alert definition name
			adNameItem = adItem.find('vrops:name', ns)
			adName = adNameItem.text
			
			# Determine alert difinition severity
			adStatesItem = adItem.find('vrops:states', ns)
			adStateItem = adStatesItem.find('vrops:state', ns)
			adSeverity = adStateItem.attrib['severity']

			# Determine alert definition impact
			adImpactItem = adStateItem.find('vrops:impact', ns)
			adDetailItem = adImpactItem.find('vrops:detail', ns)
			adImpact = adDetailItem.text

			# Output results
			print (akName, ';', rkName, ';', adName, ';', adSeverity, ';', adImpact)

