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

		# Retrieve objects
		rUrl = 'https://your-vrops-hostname/suite-api/api/adapterkinds' + '/' + akId + '/resourcekinds' + '/' + rkId + '/resources'
		resources = requests.get(rUrl, verify=False, auth=HTTPBasicAuth('username', 'password')) 
		rRoot = ElementTree.fromstring(resources.content)
		rPageInfoItem = rRoot.find('vrops:pageInfo', ns)
		rCount = rPageInfoItem.attrib['totalCount']

		# Output results
		print akName, ';', rkName, ';', rCount

