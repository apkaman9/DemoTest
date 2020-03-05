/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.erwin.jasper;

import java.io.File;
import java.io.FileInputStream;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;
import net.sf.jasperreports.engine.JRDataSource;
import net.sf.jasperreports.engine.JREmptyDataSource;
import net.sf.jasperreports.engine.JRException;
import net.sf.jasperreports.engine.JRResultSetDataSource;
import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager; 
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
import net.sf.jasperreports.engine.util.JRLoader;

/**
 *
 * @author SravanAlugubelli
 */
public class JasperCustomReport {
    StringBuilder sb=new StringBuilder();

//    public static void main(String[] args) {
//        createReport("sa", "goerwin@1");
//         
//
//    }
   
    public String createReport( String jrxmlfile_path, String outputPath, String supp_path, int mapid, Connection con,String mapName) {

        Map<String, Object> propMap = new HashMap();
        Statement stmt;
        ResultSet rs;
        JRResultSetDataSource rsdt = null;
        Properties props = new Properties();
         Map<String, Object> repoParameters=new HashMap();
         StringBuilder report_Status = new StringBuilder();
         
        try {
            String jrxmlfile=jrxmlfile_path+"MappingReportExtend.jasper";
            File sub_Path=new File(jrxmlfile);
            String get_subPath = sub_Path.getParent();
            String subPath=get_subPath+File.separator;
            
            System.out.println("jrxmlfile---->"+jrxmlfile);
            JasperReport reports = (JasperReport) JRLoader.loadObject(sub_Path);
//            JasperReport reports = JasperCompileManager.compileReport(jrxmlfile);

            props.load(new FileInputStream(supp_path));
            for (String key : props.stringPropertyNames()) {
                String values = props.getProperty(key);
                if (values.contains("?")) {
                    String Qvalue = values.replace("?", Integer.toString(mapid));
                    values = Qvalue;
                }
                System.out.println("**********************" + values);

                String query = values;
                Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");

                stmt = con.createStatement();
                rs = stmt.executeQuery(query);
                rsdt = new JRResultSetDataSource(rs);
                System.out.println("key----"+key);
                propMap.put(key, rsdt);
               
            }
            
            repoParameters= sendDataToParameters(propMap, subPath, con, mapid);
             report_Status = getReports(reports,repoParameters,outputPath,mapName,con);
        } catch (Exception e) {
            e.printStackTrace();
            sb.append(e.getMessage());
            
        }
        return sb.toString();

    }

    public Map<String, Object> sendDataToParameters(Map<String, Object> propMap, String subPath, Connection con, int mapid) {
        Map<String, Object> parameters = new HashMap<String, Object>();
        try {

            parameters.put("MAPID", Integer.toString(mapid));
            parameters.put("SUBREPORT_DIR", subPath);
            parameters.put("LICENSEDTO", "CALWIN");
            parameters.put("ANALYTIXFOOTER", "© 2018 erwin, Inc. All rights reserved");
            //parameters.put("com.ads.mm.stb.labeluserdefined1", "Jira Map Reference");
            //parameters.put("com.ads.mm.stb.labeluserdefined2", "Epic - Sprint");
            //parameters.put("com.ads.mm.stb.labeluserdefined3", "Join Component");
            //parameters.put("com.ads.mm.stb.labeluserdefined4", "Select Query");
            //parameters.put("com.ads.mm.stb.labeluserdefined5", "Extended Properties II");
            parameters.putAll(propMap);

            Statement statement = con.createStatement();
           
            ResultSet result = statement.executeQuery("  SELECT \n" +
"USER_DEFINED1 USER_DEFINED_FIELD1,USER_DEFINED2 USER_DEFINED_FIELD2,USER_DEFINED3 USER_DEFINED_FIELD3,USER_DEFINED4 USER_DEFINED_FIELD4,USER_DEFINED5 USER_DEFINED_FIELD5 \n" +
"FROM MAPPING_DETAILS map\n" +
"WHERE \n" +
"map.MAP_ID = "+mapid); 
//            parameters.put("USER_DEFINED_FIELD1", "USER_DEFINED_FIELD1");
//                parameters.put("USER_DEFINED_FIELD2", "USER_DEFINED_FIELD2");
//                parameters.put("USER_DEFINED_FIELD3", "USER_DEFINED_FIELD3");
//                parameters.put("USER_DEFINED_FIELD4", "USER_DEFINED_FIELD4");
//                parameters.put("USER_DEFINED_FIELD5", "USER_DEFINED_FIELD5");
                
            while (result.next()) { 

                String user_def1 = result.getString("USER_DEFINED_FIELD1");
                String user_def2 = result.getString("USER_DEFINED_FIELD2");
                String user_def3 = result.getString("USER_DEFINED_FIELD3");
                String user_def4 = result.getString("USER_DEFINED_FIELD4");
                String user_def5 = result.getString("USER_DEFINED_FIELD5");
             
                parameters.put("USER_DEFINED_FIELD1", user_def1);
                parameters.put("USER_DEFINED_FIELD2", user_def2);
                parameters.put("USER_DEFINED_FIELD3", user_def3);
                parameters.put("USER_DEFINED_FIELD4", user_def4);
                parameters.put("USER_DEFINED_FIELD5", user_def5);
             

            }
             ResultSet workflowrs = statement.executeQuery("SELECT TOP 1 SUBSTRING(hist.HISTORYDESC,CHARINDEX('\"toStatus\"',hist.HISTORYDESC)+12,CHARINDEX('\"fromNode\"',hist.HISTORYDESC)-CHARINDEX('\"toStatus\"',hist.HISTORYDESC)-15) AS WORKFLOW_STATE\n" +
"FROM MAPPING_DETAILS map\n" +
"INNER JOIN ADS_WORKFLOW_STATUS wfs ON wfs.OBJECT_ID = map.MAP_ID\n" +
"INNER JOIN RM_HISTORY hist ON hist.OBJECTID = wfs.OBJECT_ID and hist.OBJECTTYPEID = wfs.OBJECT_TYPE_ID\n" +
"INNER JOIN ADS_WORKFLOW_NODE wfn ON wfn.WFN_ID = wfs.WFN_ID\n" +
"INNER JOIN ADS_WORKFLOW_STAGE wstg ON wstg.WFS_ID = wfn.NODE_ID\n" +
"INNER JOIN ADS_WORKFLOW wf ON wf.WF_ID = wfn.WF_ID\n" +
"WHERE \n" +
"hist.OBJECTTYPEID = (SELECT OBJECT_TYPE_ID FROM ADS_KEY_VALUE_OBJECTS WHERE OBJECT_TYPE = 'MM_MAPPING')\n" +
"AND hist.HISTORYTYPEID = (SELECT HISTORYTYPEID FROM RM_HISTORYTYPE WHERE HISTORYTYPENAME = 'STATUSCHANGE')\n" +
"AND map.MAP_ID = "+mapid);
            
           while(workflowrs.next()){
             String workflow_string =workflowrs.getString(0) ;
             parameters.put("WORKFLOW_STATE", workflow_string);
           } 
             
             
            //createReport(reports,parameters,output_path);
        } catch (Exception e) { 

            e.printStackTrace();
             sb.append(e.getMessage());
        } 
        return parameters;
    }

    public StringBuilder getReports(JasperReport reports, Map<String, Object> parameters, String output_path,String mapName, Connection con) {
        
        try {
            JasperPrint jasperprint = JasperFillManager.fillReport(reports, parameters, con);
//            JRExporter exporter = new JRPdfExporter(); 
//            exporter.setParameter(JRExporterParameter.JASPER_PRINT, jasperprint);
            File pdfFile = new File(output_path+mapName+".pdf");
            JasperExportManager.exportReportToPdfFile(jasperprint, pdfFile.getAbsolutePath());
           // exporter.setParameter(JRExporterParameter.OUTPUT_STREAM, new FileOutputStream(output_path+"/"+mapName+".pdf"));
            //exporter.exportReport();
            System.out.println("Exported Successfully");
    