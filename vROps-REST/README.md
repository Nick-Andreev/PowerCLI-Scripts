### Description

vRealize Operations Manager offers rich REST APIs for extracting its data, such as active and inactive alerts, performance statistics, recommendations, as well as manipulating its data, such as creating notification rules. Below is two examples of how vROps REST APIs can be easily taken advantage of using Python:

* vrops_object_types_1.0.py – extracts adapters, object types and number of objects. Script gives you an idea of what is actually being monitored in vROps, by providing the number of objects you have in your vROps instance for each adapter and object type.
* vrops_alert_definitions_1.0.py – extracts adapters, object types, alert names, criticality and impact. As opposed to the first script, this script provides the list of alerts for each adapter and object type, which is helpful to identify potential alerts that can be triggered in vROps.

### Prerequisites

* Download and install Python for Windows from: https://www.python.org/downloads/windows/. When installing, make sure to check “Add Python 3.6 to PATH” option.
* Install Python "Requests" library from Windows command line:

```
> pip install requests
```

### Usage Examples

Before running the script:

* Replace vROps hostname "your-vrops-hostname" in all URLs accordingly.
* Replace "username" and "password" with your vROps credentials throughout the script.

Call scripts from Windows command line:

```
> python vrops_object_types_1.0.py
```

or

```
> python vrops_alert_definitions_1.0.py
```

### Environment Configuration

* Python 3
* vRealize Operations Manager 6.3

### Additional Information

* [Python for Windows: Quick Installation](https://niktips.wordpress.com/2017/09/07/python-for-windows-quick-installation/)
* [Extracting vRealize Operations Data Using REST API](https://niktips.wordpress.com/2017/09/17/extracting-vrealize-operations-data-using-rest-api/)
* [vRealize Operations Manager API Programming Guide](http://pubs.vmware.com/vrealizeoperationsmanager-66/topic/com.vmware.ICbase/PDF/vrealize-operations-manager-66-api-guide.pdf)
* [The ElementTree XML API](https://docs.python.org/2/library/xml.etree.elementtree.html)
* [Requests: HTTP for Humans](http://docs.python-requests.org/en/master/)

### Author

Nick Andreev:

* https://niktips.wordpress.com
* @nick_andreev_au