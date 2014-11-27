'''
Created for snmp analysis beta testing
as of 28 septembet Req-App is implemented. Req-Enc is missing. For inital structure
start few cases are considered in the Req-App.
Missing Excetion handling at all levels.

@author: Ali Danish Dept SSE TU-Chemnitz
'''
import re
from xml.dom.minidom import Document
import subprocess

def testMaxrangval():
    counter = 0
    with open('output_snmp', 'r') as file:
        mxrg = re.compile('(test-case #\d(.*): injecting valid case)')
        for line in file:
            match = re.search(mxrg, line)
            if match:
                print(match.group(), end='')
                counter = counter+1
                print(counter)
    return counter
     
def testProtosfilemod():
    bfrsz = 500000

    fi = open('output_snmp', 'r')
    fo = open('file', 'w') #modifying and making new file for 
#     k,m=0,0
    value = tuple(range(testMaxrangval()))
    print(value, type(value), len(value))   
    for line in fi.readlines():

#         k=k+1
#         print('this is k',k)
        pat = re.compile('(test-case #\d(.*): injecting valid case...\n)')
        match = re.search(pat ,line)
        if(match):
            for ind in value:
                cestr = 'test-case #{}: injecting valid case...\n'.format(ind)
                substr = '{}reply-case # {} :'.format(cestr,ind)
#                 print('value of index{}'.format(ind))  
#                 m=m+1 #checking lines that have been written
#                 print('this is m',m)
                if(line==cestr):
                    bfrsz = (re.sub(cestr, substr, line))
                    fo.write(bfrsz)
                else:
                    pass 
                
        else:
            bfrsz = line
            fo.write(bfrsz)
 
    fo.close()
    print('protos file mod completed')  

def prcstrfunc(psstr):
    testcases = {
                     'zero-case-get-req':[0,0], 'zero-case-get-next-req':[1,1], 'zero-case-set-req':[2,2],
    'get-req-version-integer':[3,376], 'get-req-requestid-integer':[377,750]
    }
    erstatus = 'ICMP_ERROR'
    erstr = psstr
    s = [int(s) for s in erstr.split() if s.isdigit()] #make space adjustments in substr testProtosfilemod()
    xvalue = s[0]
    name = list()
    ranges = list()
    for k,v in testcases.items():

        name = k
        ranges = v
        print(xvalue ,name, ranges[0], ranges[-1])# xvalue holds the error case number extracted from the string
        
        r = funcEval(xvalue, name, ranges[0], ranges[-1])
        if(r[0]==True): 
            print('the error belongs to the testgroup::',r[-1]) 
            xv = str(xvalue)
            testSnmpxml(xv, r[-1],erstatus)
            print('xml file created::snmp_result_xml.xml') 
            
def funcEval(v ,n ,rmin ,rmax):
    if v >= rmin and v <= rmax:
        return True,n
    return False,n
                    
      
def testProtos():
    psstr = ''
    testProtosfilemod()
    noerrval = 'NA'
    noergp = 'NA'
    erstatus = 'notfound'
    with open('file', 'r') as file:
              
        prpatt = re.compile('.*ERROR.*')
        for line in file:
            match = re.search(prpatt, line)
            if match:
                psstr = match.group()
                print(psstr)
                prcstrfunc(psstr)
            else:
                break
    testSnmpxml(noerrval, noergp,erstatus)
    print("xml file created::snmp_result_xml.xml")               
                
def testSnmpxml(erval, ergp, erstatus): #based on schema in full implemented system it should be consisten agreed schema
    doc = Document()
    root = doc.createElement('snmpresult')
    testname = doc.createElement('testname')
    childtestname =  root.appendChild(testname)
    childtestname.setAttribute("name", "SNMP")
    childtestname.setAttribute("verison","1.0")
    
    testmodule = doc.createElement("testmodule")
    childtestmodule = root.appendChild(testmodule)
    childtestmodule.setAttribute("modulename", "Req-App")
    childtestmodule.setAttribute("type", "Application logic test")
    
    testfileinput = doc.createElement('testfileinput')
    childtestfileinput = root.appendChild(testfileinput)
    text_testfileinput = doc.createTextNode("output_snmp.txt") #get the var substitued in final version
    childtestfileinput.appendChild(text_testfileinput)
    
    testfilemodified = doc.createElement('testfilemodified')
    childtestfilemodified = root.appendChild(testfilemodified)
    text_childtestfilemodified = doc.createTextNode('file.txt')
    childtestfilemodified.appendChild(text_childtestfilemodified)
    
    testrun = doc.createElement('testrun')
    childtestrun = root.appendChild(testrun)
    text_childtestrun = doc.createTextNode("1") #get the variable subs in final version of textnode
    childtestrun.appendChild(text_childtestrun)
    
    testcases = doc.createElement('testcases')
    childtestcases = root.appendChild(testcases)
    text_childtestcases = doc.createTextNode("10601")
    childtestcases.appendChild(text_childtestcases)
    
    totaltestgroups = doc.createElement('totaltestgroups')
    childtotaltestgroups = root.appendChild(totaltestgroups)
    text_childtotaltestgroups = doc.createTextNode("57")
    childtotaltestgroups.appendChild(text_childtotaltestgroups)
    #time elapse code      
    elapsedtime = doc.createElement('elapsedtime')
    childtestcases = root.appendChild(elapsedtime)
    text_childelapsedtime = doc.createTextNode("NA")
    childtestcases.appendChild(text_childelapsedtime)
    
    advancedop = doc.createElement('advanced-options')
    childadvancedop = root.appendChild(advancedop)
    childadvancedop.setAttribute("option","NA") #get the var subs in final ver check for activation in the main program
    text_childadvancedop = doc.createTextNode("notactivated")
    childadvancedop.appendChild(text_childadvancedop)
    #put code for successfull and other failure cases      
    testgrouperror = doc.createElement('testgrouperror')
    childtestgrouperror = root.appendChild(testgrouperror)
    childtestgrouperror.setAttribute("group", ergp) #subs var name used to output error group
    
    testfilediff = doc.createElement('testfilediff')
    childtestfilediff = root.appendChild(testfilediff)
    text_childtestfilediff = doc.createTextNode("None")
    childtestfilediff.appendChild(text_childtestfilediff)
    #put logic for successfull and other failure cases  
    testcase = doc.createElement('testcase')
    childtestcase = root.appendChild(testcase)
    childtestcase.setAttribute("errortype",erstatus)
    childtestcase.setAttribute("number", erval)  #subs var name used to output error type and number
    
    
    print(root.toprettyxml(indent = '\t'))
    resxmlfile = open("snmp_result_xml.xml","w")
    root.writexml(resxmlfile, addindent='\t' ,newl='\n')
    resxmlfile.close()
        
if __name__ == '__main__':
    testProtos()
    
