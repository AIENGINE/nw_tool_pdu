'''
Created for snmp task/job interpretation script.
As of 28 sept14 initial startup unrepsonsiveness is considered for beta.
Missing xml reporting based on initial startup errors and exception handling at all levels.S
 


@author: Ali Danish Dept SSE TU-Chemnitz
'''

import subprocess
import re
import os
import signal
from xml.dom import minidom

def testfun():

    
    doc = minidom.parse('jobxmldumy.xml')
#     varelem = doc.getElementsByTagName('Variable')


#     print (varelem.item(0).getAttribute('VarName'))
    for varelm in doc.getElementsByTagName('Variable'):
#         print(varelm.getAttribute('VarName'))
        if (varelm.getAttribute('VarName') == 'PDU-IP'):
            valip = varelm.getAttribute('VarValue')
            print('the ip for job uid 15 found',valip)
        elif (varelm.getAttribute('VarName') == "Req-App"):
            valcmd = varelm.getAttribute('VarValue')
            print('command for req-app',valcmd)
        elif (varelm.getAttribute('VarName') == "Req-Enc"):
            valcmd2 = varelm.getAttribute('VarValue')
            print('command for req-enc',valcmd2)    
        elif(varelm.getAttribute('VarName') == 'Advanced-Options'): #to uniquely identify options for snmp VarName should be unique than the rest of jobs
            valop = varelm.getAttribute('VarValue')
            print('option for command', valop)

    outcmd1 = valcmd+' '+valip
    outproc0 = subprocess.Popen('ping -c 4'+' '+valip,stdout=subprocess.PIPE, stderr = subprocess.PIPE,shell=True)
    outproc0.wait()
    

    if (outproc0.returncode == 0):
        snmpcall(outcmd1)

      
    elif (outproc0.returncode == 1):
        print('Valid IP not responding or destination unreachable')
        #resultxml is called here 
    else:
        print("raise exception here...")  
            

def snmpcall(cmd):
    
        pat1 = re.compile(b'(waiting \d\d\d\d ms for reply...0 bytes received\n)') 
        pat2 = re.compile(b'(waiting \d\d\d ms for reply...\d\d(.*) bytes received)')     
        outproc1 = subprocess.Popen(cmd+' | tee output_snmp',stdout=subprocess.PIPE, stderr = subprocess.PIPE, shell=True) 
        
        for line in outproc1.stdout:

            matchdata1 = re.search(pat1 ,line)
            matchdata2 = re.search(pat2, line)
            if (matchdata1):
                print(matchdata1,'......response not detected exiting the program.....')
                outproc1.stdout.flush()
           
                os.killpg(0, signal.SIGKILL) 
            
                
            elif (matchdata2): 
                 
                print('.........response detected.........logging continues............')
                outproc1.stdout.flush() 

   
            else:
                outproc1.stdout.flush()  
                print(line)
        outproc1.wait()        
        print(outproc1.returncode)
        if (outproc1.returncode == 0):
            print("......file :: output_snmp has been created.................")
            print("..........continuing analysis.................")
            snmpProc = subprocess.Popen('python3.1 snmpAnalysis.py', shell=True)
            snmpProc.wait()
            print('...........Finished result is READY...................')
                
                  

if __name__ == '__main__':
    testfun()
    
    