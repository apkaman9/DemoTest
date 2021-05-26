/****** Object:  StoredProcedure [dbo].[usp_DM_MPF_TransferOfCustodian]    Script Date: 5/23/2018 1:58:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
------------------------------------------------------------------------------------------------------------
Object: usp_DM_MPF_TransferOfCustodian
------------------------------------------------------------------------------------------------------------
Version          Date            Author                 Description
------------------------------------------------------------------------------------------------------------
Data Mart			9/30/2008	S N Lakkani				Object created for DM Project in LAS, This SP is executed 
														to create the Datamart File DM_MPF_TransferOfCustodian_XX.txt
Data Mart			10/31/2008  Kirti Chandra Sahu		Modified to include ORDER BY clause in the script.
Data Mart			01/05/2009  Varun Bhatt     		Modified the logic for TOC as per the Banks Process  
Datamart 10.0		3/13/2013   Padmini Jyotishmati   	TFS#3683; Seattle project. Display records for Seattle and filter out FNMA Data.                                               
DM 11.0				2013-06-4   Sona Sharma  			TFS:3726 :: Additional investor
														Removed the hardcoded HLBs participation from dbo.DM_Select_PFICriteria ,dbo.DM_Select_MCCriteria
Datamat 11.0		06/05/2013  NISHA MAKWANA			TFS#3726::AI::Change length of variable @MCOwner to 100              
DataMart 11.0		10/11/2013	Ajinkya Korade			Undo Seattle :: TFS : 4025 :: Removed Seattle Conditions
DM 11 HF8			2013-10-30	Avdhut Vaidya			TFS#4091 :: item#1453 :: Undo Seattle/Datamart/DM_MPF_PFI_5692 is empty
														Corrected the comparison of PFiBuyerOwningMPFBankiD = @HLBNumber
														- The PFiBuyerOwningMPFBankiD is actually OrgKEY and not OrgiD
														- Created a new variable to hold OrgKey based on @HLBNumber
														  and using this variable in WHERE clause
DataMart 140HF34	2014/03/04	Ajinkya Korade			TFS#4409 :: item#1763 :: AIPhase1 :: Corrected joins in the stored procedure.
														- Added parenthesis to change the precedence for logical operators ANDs & ORs while selecting data for PFI.
														Removed all unwanted joins :
															- Removed Left Outer Join on loan And Joined [MasterCommitmentTableView] with TOCD1 on Manumber directly to get the 
															Valid Master Commitments. 
															- Removed unwanted joins of MCParty and Loan and Joined UV_DeliveryCommitmentTableView with TOCD1 on DeliverycommitmentNumber
															to get valid Delivery Commitments
Datamart			04/01/2014	Sean Saville			Modifying date formatting logic to properly format October dates (where month = '10')
AG               6/15/2016       Aditi                   TFS#8086 :: Removed linked server refrence.
------------------------------------------------------------------------------------------------------------
*/

CREATE PROCEDURE [dbo].[usp_DM_MPF_TransferOfCustodian]
	@HLBNumber INT
AS
BEGIN
	BEGIN TRY
	DECLARE	@OrgKEY iNT
	--TFS:4091 :: item#1453 - using this new variable to hold OrgKEY for using in the WHERE clause of the main query
	SELECT	@OrgKEY = OrgKEY
	FROM	[LOS_Prod].dbo.UV_FHLBankTableView
	WHERE	HLBNumber = @HLBNumber

	--TFS#3726::AI::Change length of variable @MCOwner to 100
	DECLARE	@MCOwner	VARCHAR(100)
	SET		@MCOwner = (SELECT	Org.[Name] 
						FROM	[LOS_Prod].dbo.Org Org 
						LEFT OUTER JOIN	(	SELECT  DISTINCT OrgKey 
											FROM	[LOS_Prod].dbo.OrgServicingModelRole OSMR 
											WHERE	RoleKey=1 AND DateTo IS NULL
										) OSMR 
						ON		OSMR.OrgKEY=Org.OrgKEY
						WHERE	Org.OrgKEY = @OrgKEY)

	SELECT TOP 100 PERCENT TOC.* FROM 
	(
	SELECT 
		TOCD1.LCSTRDTOCRecertDueDate, 
		TOCD1.LCSTRDTOCRecertDate, 
		TOCD1.PFINUMBER, 
		TOCD1.MANumber, 
		TOCD1.DeliveryCommitmentNumber, 
		TOCD1.LoanNumber, 
		TOCD1.LCSTOCHEffectiveDate, 
		TOCD1.LCSTOCHCustodianID,  
		TOCD1.LCSTOCHTOCHeaderID 
	FROM 
		(
		SELECT
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDueDate)),' ',0),' ') as LCSTRDTOCRecertDueDate,
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDate)),' ',0),' ') as LCSTRDTOCRecertDate,
			CAST(CASE	WHEN TOCD.LCSTOCDEntityTypeID = '2' 
						THEN CONVERT(Integer, TOCD.LCSTOCDEntityID) 
				END AS INTEGER) AS PFINUMBER, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '3' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS MANumber,
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '5' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS DeliveryCommitmentNumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '6' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS LoanNumber, 
			ISNULL(replace(ltrim(replace(month(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(LCSTOCHEffectiveDate)),' ',0),' ') as LCSTOCHEffectiveDate,
			'"' + TOCH.LCSTOCHCustodianID + '"' AS LCSTOCHCustodianID, 
			TOCH.LCSTOCHTOCHeaderID
			--TFS#8086 -Aditi Dubey  Removed linked server refrence 
		FROM	[LCS_Prod].dbo.LCS_TransferOfCustodianDetail TOCD 
				LEFT OUTER JOIN	[LCS_Prod].dbo.LCS_TransferOfCustodianHeader TOCH 
					ON	TOCD.LCSTOCDTOCHeaderID = TOCH.LCSTOCHTOCHeaderID 
				LEFT OUTER JOIN [LCS_Prod].dbo.LCS_TOCRecertDate TOCRD 
					ON TOCD.LCSTOCDTOCHeaderID = TOCRD.LCSTRDTOCHeaderID
		)TOCD1 
		LEFT OUTER JOIN	[LOS_Prod].dbo.[Loan] loan 
			ON loan.LoanNumber = TOCD1.LoanNumber
		LEFT OUTER JOIN [MasterCommitmentTableView] MC 
			ON MC.MANumber=loan.MANumber
		LEFT OUTER JOIN [LOS_Prod].dbo.MCModelType MT 
			ON MC.MCModelTypeKey=MT.MCModelTypeKey 
		LEFT OUTER JOIN dbo.DM_Select_MCCriteria   -- TFS:3726
			ON MC.MANumber = DM_Select_MCCriteria.MANumber	-- TFS#3726
	WHERE	(
			--TFS#3726 :: Corrected Where Clause where the organization is MAOwner or Participate in the loan. - Ajinkya Korade
			MC.MAOwner = ltrim(rtrim(@MCOwner)) 
			OR	(DM_Select_MCCriteria.ParticipationOrgKey = @OrgKEY     --TFS#3726 
				AND DM_Select_MCCriteria.MaxParticipationPercent > 0)  
			)
			AND MT.ServicingModelKey NOT in (2,4)

	UNION

	SELECT DISTINCT  
		TOCD1.LCSTRDTOCRecertDueDate, 
		TOCD1.LCSTRDTOCRecertDate, 
		TOCD1.PFINUMBER, 
		TOCD1.MANumber, 
		TOCD1.DeliveryCommitmentNumber, 
		TOCD1.LoanNumber, 
		TOCD1.LCSTOCHEffectiveDate, 
		TOCD1.LCSTOCHCustodianID,  
		TOCD1.LCSTOCHTOCHeaderID 
	FROM 
		(
		SELECT
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDueDate)),' ',0),' ') as LCSTRDTOCRecertDueDate,
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDate)),' ',0),' ') as LCSTRDTOCRecertDate,
			CAST(CASE	WHEN TOCD.LCSTOCDEntityTypeID = '2' 
						THEN CONVERT(Integer, TOCD.LCSTOCDEntityID) 
				END AS INTEGER) AS PFINUMBER,
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '3' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS MANumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '5' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS DeliveryCommitmentNumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '6' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS LoanNumber, 
			ISNULL(replace(ltrim(replace(month(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(LCSTOCHEffectiveDate)),' ',0),' ') as LCSTOCHEffectiveDate,
			'"' + TOCH.LCSTOCHCustodianID + '"' AS LCSTOCHCustodianID, 
			TOCH.LCSTOCHTOCHeaderID
			--TFS#8086 -Aditi Dubey  Removed linked server refrence 
		FROM	[LCS_Prod].dbo.LCS_TransferOfCustodianDetail TOCD 
				LEFT OUTER JOIN [LCS_Prod].dbo.LCS_TransferOfCustodianHeader TOCH 
					ON TOCD.LCSTOCDTOCHeaderID = TOCH.LCSTOCHTOCHeaderID 
				LEFT OUTER JOIN [LCS_Prod].dbo.LCS_TOCRecertDate TOCRD 
					ON TOCD.LCSTOCDTOCHeaderID = TOCRD.LCSTRDTOCHeaderID
		)TOCD1
		/*TFS#4409 :: item#1763 :: AI Phase 1 :: Ajinkya Korade - Removed Left Outer Join on loan And Joined [MasterCommitmentTableView] with 
		TOCD1 on Manumber directly to get valid MasterCommitments - 2014\03\04 */
		LEFT OUTER JOIN [MasterCommitmentTableView] MC 
			ON MC.MANumber=TOCD1.MANumber 
		INNER JOIN [LOS_Prod].dbo.MasterCommitment MC1 
			ON MC.MANumber = MC1.MasterCOMmitmentID 
		LEFT OUTER JOIN [LOS_Prod].dbo.MCModelType MT 
			ON MC.MCModelTypeKey=MT.MCModelTypeKey 
		LEFT OUTER JOIN [LOS_Prod].dbo.MCParty mcp 
			ON	mcp.MasterCommitmentKey = MC1.MasterCommitmentKey 
			AND mcp.RoleKey = 1 
			AND mcp.OrgKey = @OrgKEY 
			AND mcp.ParticipationTypeInd = 3
		LEFT OUTER JOIN DM_Select_MCCriteria 
			ON MC.MANumber = DM_Select_MCCriteria.MANumber
	WHERE   DM_Select_MCCriteria.ParticipationOrgKey = @OrgKEY AND (DM_Select_MCCriteria.MaxParticipationPercent > 0) AND (MT.ServicingModelKey NOT in (2,4)) AND (NOT (MC.MAStatusCode = 'SM06')) 
			OR  (MT.ServicingModelKey NOT in (2,4)) AND ((mcp.ParticipationPercent > 0 )) AND (NOT (MC.MAStatusCode = 'SM06')) 
			OR	(MT.ServicingModelKey NOT in (2,4)) AND (MC.MAOwner = ltrim(rtrim(@MCOwner)))  AND (NOT (MC.MAStatusCode = 'SM06'))

	UNION

	SELECT DISTINCT
		TOCD1.LCSTRDTOCRecertDueDate, 
		TOCD1.LCSTRDTOCRecertDate, 
		TOCD1.PFINUMBER, 
		TOCD1.MANumber, 
		TOCD1.DeliveryCommitmentNumber, 
		TOCD1.LoanNumber, 
		TOCD1.LCSTOCHEffectiveDate, 
		TOCD1.LCSTOCHCustodianID,  
		TOCD1.LCSTOCHTOCHeaderID 
	FROM 
		(
		SELECT
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDueDate)),' ',0),' ') as LCSTRDTOCRecertDueDate,
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDate)),' ',0),' ') as LCSTRDTOCRecertDate,
			CAST(CASE	WHEN TOCD.LCSTOCDEntityTypeID = '2' 
						THEN CONVERT(Integer, TOCD.LCSTOCDEntityID) 
				END AS INTEGER) AS PFINUMBER, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '3' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS MANumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '5' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS DeliveryCommitmentNumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '6' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS LoanNumber, 
			ISNULL(replace(ltrim(replace(month(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(LCSTOCHEffectiveDate)),' ',0),' ') as LCSTOCHEffectiveDate,
			'"' + TOCH.LCSTOCHCustodianID + '"' AS LCSTOCHCustodianID, 
			TOCH.LCSTOCHTOCHeaderID
			--TFS#8086 -Aditi Dubey  Removed linked server refrence 
		FROM	[LCS_Prod].dbo.LCS_TransferOfCustodianDetail TOCD 
				LEFT OUTER JOIN	[LCS_Prod].dbo.LCS_TransferOfCustodianHeader TOCH 
					ON TOCD.LCSTOCDTOCHeaderID = TOCH.LCSTOCHTOCHeaderID 
				LEFT OUTER JOIN	[LCS_Prod].dbo.LCS_TOCRecertDate TOCRD 
					ON TOCD.LCSTOCDTOCHeaderID = TOCRD.LCSTRDTOCHeaderID
		) TOCD1
		/*TFS#4409 :: item#1763 :: AI Phase 1 :: Ajinkya Korade - Removed unwanted joins of MCParty and Loan and joined 
		  UV_DeliveryCommitmentTableView with TOCD1 on DeliverycommitmentNumber to get valid Delivery Commitments - 2014\03\04*/
		LEFT OUTER JOIN [LOS_Prod].dbo.UV_DeliveryCommitmentTableView DeliveryCommitmentTableView 
			ON  TOCD1.DeliveryCommitmentNumber = DeliveryCommitmentTableView.DeliveryCommitmentNumber
		LEFT OUTER JOIN [MasterCommitmentTableView] MC 
			ON  MC.MANumber=DeliveryCommitmentTableView.MANumber   
		INNER JOIN [LOS_Prod].dbo.MasterCommitment MC1 
			ON  MC.MANumber = MC1.MasterCommitmentID
		LEFT OUTER JOIN [LOS_Prod].dbo.DCParty dcp 
			ON  dcp.DeliveryCommitmentKey = DeliveryCommitmentTableView.DeliveryCommitmentKey 
			AND dcp.ORGKEY = @OrgKEY 
			AND dcp.RoleKEY = 1 
			AND MPFBankInd = 3 
		LEFT OUTER JOIN [LOS_Prod].dbo.MCModelType MT 
			ON  MC.MCModelTypeKey=MT.MCModelTypeKey 
		--TFS#4409 :: item#1763 :: AI Phase 1 :: Ajinkya Korade - Removed Join with MCParty as it is not required - 2014\03\04
		LEFT OUTER JOIN dbo.DM_Select_MCCriteria
			ON MC.MANumber = DM_Select_MCCriteria.MANumber
	WHERE	(
				MC.MAOwner = ltrim(rtrim(@MCOwner)) 
				OR	(
					DM_Select_MCCriteria.ParticipationOrgKey = @OrgKEY 
					AND dcp.ParticipationPercent > 0
					)
			)
			AND MT.ServicingModelKey NOT in (2,4)

	UNION 

	SELECT
		TOCD1.LCSTRDTOCRecertDueDate, 
		TOCD1.LCSTRDTOCRecertDate, 
		TOCD1.PFINUMBER, 
		TOCD1.MANumber, 
		TOCD1.DeliveryCommitmentNumber, 
		TOCD1.LoanNumber, 
		TOCD1.LCSTOCHEffectiveDate, 
		TOCD1.LCSTOCHCustodianID,  
		TOCD1.LCSTOCHTOCHeaderID 
	FROM 
		(
		SELECT
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDueDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDueDate)),' ',0),' ') as LCSTRDTOCRecertDueDate,
			ISNULL(replace(ltrim(replace(month(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(TOCRD.LCSTRDTOCRecertDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(TOCRD.LCSTRDTOCRecertDate)),' ',0),' ') as LCSTRDTOCRecertDate,
			CAST(CASE	WHEN TOCD.LCSTOCDEntityTypeID = '2' 
						THEN CONVERT(Integer, TOCD.LCSTOCDEntityID) 
				END AS INTEGER) AS PFINUMBER, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '3' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS MANumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '5' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS DeliveryCommitmentNumber, 
			CASE	WHEN TOCD.LCSTOCDEntityTypeID = '6' 
					THEN CAST(TOCD.LCSTOCDEntityID AS Integer) 
			END AS LoanNumber, 
			ISNULL(replace(ltrim(replace(month(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(ltrim(replace(day(LCSTOCHEffectiveDate),0,' ')),' ',0) + '/' + replace(Convert(varchar(10),year(LCSTOCHEffectiveDate)),' ',0),' ') as LCSTOCHEffectiveDate,
			'"' + TOCH.LCSTOCHCustodianID + '"' AS LCSTOCHCustodianID, 
			TOCH.LCSTOCHTOCHeaderID
			--TFS#8086 -Aditi Dubey  Removed linked server refrence 
		FROM	[LCS_Prod].dbo.LCS_TransferOfCustodianDetail TOCD 
				LEFT OUTER JOIN [LCS_Prod].dbo.LCS_TransferOfCustodianHeader TOCH 
					ON TOCD.LCSTOCDTOCHeaderID = TOCH.LCSTOCHTOCHeaderID 
				LEFT OUTER JOIN [LCS_Prod].dbo.LCS_TOCRecertDate TOCRD 
					ON TOCD.LCSTOCDTOCHeaderID = TOCRD.LCSTRDTOCHeaderID
		) TOCD1
		LEFT OUTER JOIN dbo.PFITableView PFITV 
			ON TOCD1.PFINUMBER = PFITV.PFINumber
		LEFT OUTER JOIN dbo.DM_Select_PFICriteria   -- TFS:3726
			ON PFITV.PFINumber = DM_Select_PFICriteria.PFINumber    -- TFS:3726
	WHERE	(
	/*TFS#4409 :: item#1763 :: AIPhase 1 ::Ajinkya Korade - Added parenthesis in order to give correct results
	original criteria was like (Organization is Owner) OR (Organization is Partipating) AND (ServicingModelKey is not in 2,4)
	as AND precedence over OR thus interpreting it as (Organization is Owner) OR ((Organization is Partipating) AND (ServicingModelKey is not in 2,4))
	Thus corrected it as ((Organization is Owner) OR (Organization is Partipating)) AND (ServicingModelKey is not in 2,4) which is a valid criteria
	- 2014\03\04*/
			PFITV.PFIOwner = ltrim(rtrim(@MCOwner)) 
			OR	
				(
				DM_Select_PFICriteria.ParticipationOrgKey = @OrgKEY 
				AND DM_Select_PFICriteria.MaxParticipationPercent > 0 
				)
			)
			AND PFITV.ServicingModelKey NOT IN (2,4)
	)
	TOC
	ORDER BY TOC.LCSTOCHTOCHeaderID ASC

	END TRY


	BEGIN CATCH
	 PRINT 'Error Retrieving data'
	END CATCH

END


GO
/****** Object:  StoredProcedure [dbo].[usp_DM_MPFLoan_AgentFeeInfo_Insert]    Script Date: 5/23/2018 1:58:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





/*
* Description: Will Insert records into the MPFFHLBDW database table "DM_MPFLoan_AgentFeeInfo" 
* Author Kirti Sahu
* Created: 10/01/2008 
*/

CREATE  PROCEDURE [dbo].[usp_DM_MPFLoan_AgentFeeInfo_Insert]
AS

Truncate Table [dbo].[DM_MPFLoan_AgentFeeInfo]

INSERT INTO [dbo].[DM_MPFLoan_AgentFeeInfo](
	[LoanNumber], 
	[AgentFeePayDate], 
	[AgentFeePayAmount]
)
SELECT DISTINCT 
	dbo.LoanView.LoanNumber, 
	dbo.DM_MPFLoan_GetAgentFee.MaxOfAgentFeePaymentDate AS AgentFeePayDate, 
	ISNULL(dbo.DM_MPFLoan_GetAgentFee.SumofAgentFeePaymentAmount, 0) AS AgentFeePayAmount
FROM	dbo.LoanView WITH (NOLOCK) INNER JOIN dbo.DM_MPFLoan_GetAgentFee ON 
	dbo.LoanView.LoanNumber = dbo.DM_MPFLoan_GetAgentFee.LoanNumber
ORDER BY dbo.LoanView.LoanNumber



GO
