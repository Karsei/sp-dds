/************************************************************************
 * Dynamic Dollar Shop - CORE (Sourcemod)
 * 
 * Copyright (C) 2012-2015 Karsei
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 * 
 ***********************************************************************/
#include <sourcemod>
#include <geoip>
#include <dds>

#define _DEBUG_

/*******************************************************
 * E N U M S
*******************************************************/
enum Apply
{
	DBIDX,
	ITEMIDX
}

enum SettingItem
{
	CATECODE,
	bool:VALUE
}

enum Item
{
	INDEX,
	String:NAME[64],
	CATECODE,
	MONEY,
	HAVTIME,
	String:ENV[256]
}

enum ItemCG
{
	String:NAME[64],
	CODE,
	String:ENV[256]
}


/*******************************************************
 * V A R I A B L E S
*******************************************************/
// SQL 데이터베이스
Database dds_hSQLDatabase = null;

// 로그 파일
char dds_sPluginLogFile[256];

// Convar 변수
ConVar dds_hCV_PluginSwitch;
ConVar dds_hCV_SwtichLogData;
ConVar dds_hCV_SwitchDisplayChat;
ConVar dds_hCV_SwitchQuickCmdN;
ConVar dds_hCV_SwitchQuickCmdF1;
ConVar dds_hCV_SwitchQuickCmdF2;
ConVar dds_hCV_SwitchGiftMoney;
ConVar dds_hCV_SwitchGiftItem;
ConVar dds_hCV_SwitchResellItem;
ConVar dds_hCV_ItemMoneyMultiply;
ConVar dds_hCV_ItemResellRatio;

// 팀 채팅
bool dds_bTeamChat[MAXPLAYERS + 1];

// 아이템
int dds_iItemCount;
int dds_eItem[DDS_ENV_ITEM_MAX + 1][Item];

// 아이템 종류
int dds_iItemCategoryCount;
int dds_eItemCategoryList[DDS_ENV_ITEMCG_MAX + 1][ItemCG];

// 유저 소유
int dds_iUserMoney[MAXPLAYERS + 1];
int dds_iUserAppliedItem[MAXPLAYERS + 1][DDS_ENV_ITEMCG_MAX + 1][Apply];
bool dds_eUserItemCGStatus[MAXPLAYERS + 1][DDS_ENV_ITEMCG_MAX + 1][SettingItem];

/*******************************************************
 * P L U G I N  I N F O R M A T I O N
*******************************************************/
public Plugin:myinfo = 
{
	name = DDS_ENV_CORE_NAME,
	author = DDS_ENV_CORE_AUTHOR,
	description = "DOLLAR SHOP",
	version = DDS_ENV_CORE_VERSION,
	url = DDS_ENV_CORE_HOMEPAGE
};

/*******************************************************
 * F O R W A R D   F U N C T I O N S
*******************************************************/
/**
 * 플러그인 시작 시
 */
public void OnPluginStart()
{
	// Version 등록
	CreateConVar("sm_dynamicdollarshop_version", DDS_ENV_CORE_VERSION, "Made By. Karsei", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	// Convar 등록
	dds_hCV_PluginSwitch = CreateConVar("dds_switch_plugin", "1", "본 플러그인의 작동 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwtichLogData = CreateConVar("dds_switch_log_data", "1", "데이터 로그 작성 여부입니다. 활성화를 권장합니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwitchDisplayChat = CreateConVar("dds_switch_chat", "0", "채팅을 할 때 메세지 출력 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwitchQuickCmdN = CreateConVar("dds_switch_quick_n", "1", "N키의 단축키 설정입니다. 0 - 작동 해제 / 1 - 메인 메뉴 / 2 - 인벤토리 메뉴", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwitchQuickCmdF1 = CreateConVar("dds_switch_quick_f1", "0", "F1키의 단축키 설정입니다. 0 - 작동 해제 / 1 - 메인 메뉴 / 2 - 인벤토리 메뉴", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	dds_hCV_SwitchQuickCmdF2 = CreateConVar("dds_switch_quick_f2", "0", "F2키의 단축키 설정입니다. 0 - 작동 해제 / 1 - 메인 메뉴 / 2 - 인벤토리 메뉴", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	dds_hCV_SwitchGiftMoney = CreateConVar("dds_switch_gift_money", "1", "금액 선물 기능을 기본적으로 허용할 것인지의 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwitchGiftItem = CreateConVar("dds_switch_gift_item", "1", "아이템 선물 기능을 기본적으로 허용할 것인지의 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_SwitchResellItem = CreateConVar("dds_switch_item_resell", "0", "아이템 되팔기 기능을 기본적으로 허용할 것인지의 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dds_hCV_ItemMoneyMultiply = CreateConVar("dds_item_money_multiply", "1.0", "모든 아이템을 각 아이템 금액의 몇 배의 비율로 설정할 것인지 적어주세요. 처음 아이템 목록을 로드할 때 반영됩니다.", FCVAR_PLUGIN);
	dds_hCV_ItemResellRatio = CreateConVar("dds_item_resell_ratio", "0.2", "아이템 되팔기 기능을 사용할 때 해당 아이템 금액의 어느 정도의 비율로 설정할 것인지 적어주세요.", FCVAR_PLUGIN);

	// 플러그인 로그 작성 등록
	BuildPath(Path_SM, dds_sPluginLogFile, sizeof(dds_sPluginLogFile), "logs/dynamicdollarshop.log");

	// 번역 로드
	LoadTranslations("dynamicdollarshop.phrases");

	// 콘솔 커맨드 연결
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_TeamSay);
}

/**
 * API 등록
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// 라이브러리 등록
	RegPluginLibrary("dds_core");

	// Native 함수 등록
	CreateNative("DDS_IsPluginOn", Native_DDS_IsPluginOn);
	CreateNative("DDS_GetClientMoney", Native_DDS_GetClientMoney);
	CreateNative("DDS_GetClientAppliedDB", Native_DDS_GetClientAppliedDB);
	CreateNative("DDS_GetClientAppliedItem", Native_DDS_GetClientAppliedItem);

	return APLRes_Success;
}

/**
 * 설정이 로드되고 난 후
 */
public void OnConfigsExecuted()
{
	// 플러그인이 꺼져 있을 때는 동작 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	/** SQL 데이터베이스 연결 **/
	//Database.Connect(SQL_GetDatabase, "dds");
	SQL_TConnect(SQL_GetDatabase, "dds");

	/** 단축키 연결 **/
	// N 키
	if (dds_hCV_SwitchQuickCmdN.IntValue == 1)	RegConsoleCmd("nightvision", Menu_Main);
	else if (dds_hCV_SwitchQuickCmdN.IntValue == 2)	RegConsoleCmd("nightvision", Menu_Inven);
	// F1키
	if (dds_hCV_SwitchQuickCmdF1.IntValue == 1)	RegConsoleCmd("autobuy", Menu_Main);
	else if (dds_hCV_SwitchQuickCmdF1.IntValue == 2)	RegConsoleCmd("autobuy", Menu_Inven);
	// F2키
	if (dds_hCV_SwitchQuickCmdF2.IntValue == 1)	RegConsoleCmd("rebuy", Menu_Main);
	else if (dds_hCV_SwitchQuickCmdF2.IntValue == 2)	RegConsoleCmd("rebuy", Menu_Inven);
}

/**
 * 맵이 종료된 후
 */
public void OnMapEnd()
{
	// SQL 데이터베이스 핸들 초기화
	if (dds_hSQLDatabase != null)
	{
		delete dds_hSQLDatabase;
	}
	dds_hSQLDatabase = null;
}

/**
 * 클라이언트가 접속하면서 스팀 고유번호를 받았을 때
 *
 * @param client			클라이언트 인덱스
 * @param auth				클라이언트 고유 번호(타입 2)
 */
public void OnClientAuthorized(client, const String:auth[])
{
	// 플러그인이 꺼져 있을 때는 동작 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	// 봇은 제외
	if (IsFakeClient(client))	return;

	// 유저 데이터 초기화
	Init_UserData(client, 2);

	// 유저 정보 확인
	CreateTimer(0.4, SQL_Timer_UserLoad, client);
}

/**
 * 클라이언트가 서버로부터 나가고 있을 때
 *
 * @param client			클라이언트 인덱스
 */
public void OnClientDisconnect(client)
{
	// 게임에 없으면 통과
	if (!IsClientInGame(client))	return;

	// 봇은 제외
	if (IsFakeClient(client))	return;

	// 클라이언트 고유 번호 추출
	char sUsrAuthId[20];
	GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

	// 오류 검출 생성
	ArrayList hMakeErr = CreateArray(8);
	hMakeErr.Push(client);
	hMakeErr.Push(1013);

	// 유저 정보 갱신
	char sSendQuery[256];

	Format(sSendQuery, sizeof(sSendQuery), "UPDATE `dds_user_profile` SET `ingame` = '0' WHERE `authid` = '%s'", sUsrAuthId);
	dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErr);

	// 유저 데이터 초기화
	Init_UserData(client, 2);

	#if defined _DEBUG_
	DDS_PrintToServer(":: DEBUG :: User Disconnect - Update (client: %N)", client);
	#endif
}


/*******************************************************
 G E N E R A L   F U N C T I O N S
*******************************************************/
/**
 * 초기화 :: 서버 데이터
 */
public void Init_ServerData()
{
	/** 아이템 **/
	// 아이템 갯수
	dds_iItemCount = 0;
	// 아이템 목록
	for (int i = 0; i <= DDS_ENV_ITEM_MAX; i++)
	{
		dds_eItem[i][INDEX] = 0;
		Format(dds_eItem[i][NAME], 64, "");
		dds_eItem[i][CATECODE] = 0;
		dds_eItem[i][MONEY] = 0;
		dds_eItem[i][HAVTIME] = 0;
		Format(dds_eItem[i][ENV], 256, "");
	}
	// 아이템 0번 'X' 설정
	Format(dds_eItem[0][NAME], 64, "EN:X");

	/** 아이템 종류 **/
	// 아이템 종류 갯수
	dds_iItemCategoryCount = 0;
	// 아이템 종류 목록
	for (int i = 0; i <= DDS_ENV_ITEMCG_MAX; i++)
	{
		Format(dds_eItemCategoryList[i][NAME], 64, "");
		dds_eItemCategoryList[i][CODE] = 0;
		Format(dds_eItemCategoryList[i][ENV], 256, "");
	}
	// 아이템 종류 0번 '전체' 설정
	Format(dds_eItemCategoryList[0][NAME], 64, "EN:Total||KO:전체");

	#if defined _DEBUG_
	DDS_PrintToServer(":: DEBUG :: Server Data Initialization Complete");
	#endif
}

/**
 * 초기화 :: 유저 데이터
 *
 * @param client			클라이언트 인덱스
 * @param mode				처리 모드(1 - 전체 초기화, 2 - 특정 클라이언트 초기화)
 */
public void Init_UserData(int client, int mode)
{
	switch (mode)
	{
		case 1:
		{
			/** 전체 초기화 **/
			for (int i = 0; i <= MAXPLAYERS; i++)
			{
				// 팀 채팅
				dds_bTeamChat[i] = false;

				// 금액
				dds_iUserMoney[i] = 0;

				// 아이템 관련
				for (int k = 0; k <= DDS_ENV_ITEMCG_MAX; k++)
				{
					// 아이템 장착 상태
					dds_iUserAppliedItem[i][k][DBIDX] = 0;
					dds_iUserAppliedItem[i][k][ITEMIDX] = 0;

					// 아이템 종류 활성 상태
					dds_eUserItemCGStatus[i][k][CATECODE] = 0;
					dds_eUserItemCGStatus[i][k][VALUE] = false;
				}
			}
		}
		case 2:
		{
			/** 특정 클라이언트 초기화 **/
			// 팀 채팅
			dds_bTeamChat[client] = false;

			// 금액
			dds_iUserMoney[client] = 0;

			// 아이템 관련
			for (int i = 0; i <= DDS_ENV_ITEMCG_MAX; i++)
			{
				// 아이템 장착 상태
				dds_iUserAppliedItem[client][i][DBIDX] = 0;
				dds_iUserAppliedItem[client][i][ITEMIDX] = 0;

				// 아이템 종류 활성 상태
				dds_eUserItemCGStatus[client][i][CATECODE] = 0;
				dds_eUserItemCGStatus[client][i][VALUE] = false;
			}
		}
	}

	#if defined _DEBUG_
	DDS_PrintToServer(":: DEBUG :: User Data Initialization Complete (client: %N, mode: %d)", client, mode);
	#endif
}


/**
 * System :: 데이터 처리 시스템
 *
 * @param client			클라이언트 인덱스
 * @param process			행동 구별
 * @param data				추가 파라메터
 */
public void System_DataProcess(int client, const char[] process, const char[] data)
{
	/******************************************************************************
	 * A T T E N S I O N  / 주의
	 ******************************************************************************
	 *
	 * 중요 부분이니 함부로 건들지 말 것
	 * 데이터가지고 놀기 때문에 잘못하면 엄청나게 잘못될 수 있으므로 주의
	 *
	 * 데이터를 처리할 때는 행동별로 다양하고 동적인게 많으므로 배열로
	 * 처리하는 것보다는 문자열로 값을 하나하나 항목별로 전해주어
	 * 원하는 항목을 잘라 처리하는게 좋아 보여 'data' 파라메터를 만들어 
	 * 처리해야 하는 항목만 전달할 수 있도록 변경
	 * 
	*******************************************************************************/
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	/***** 클라이언트 정보 추출 *****/
	// 클라이언트의 이름 파악
	char sClient_Name[32];
	GetClientName(client, sClient_Name, sizeof(sClient_Name));

	// 클라이언트의 고유 번호 파악
	char sClient_AuthId[20];
	GetClientAuthId(client, AuthId_SteamID64, sClient_AuthId, sizeof(sClient_AuthId));

	// 쿼리 구문 준비
	char sSendQuery[512];

	// 버퍼 준비
	char sBuffer[128];

	/******************************************************************************
	 * -----------------------------------
	 * 'process' 파라메터 종류 별 나열
	 * -----------------------------------
	 *
	 * 'buy' - 아이템 구매
	 * 'inven-use' - 인벤토리에서의 아이템 사용하기
	 * 'inven-resell' - 인벤토리에서의 아이템 되팔기
	 * 'inven-gift' - 인벤토리에서의 아이템 선물하기
	 * 'inven-drop' - 인벤토리에서의 아이템 버리기
	 * 'curitem-cancel' - 내 장착 아이템에서의 장착 해제
	 * 'curitem-use' - 내 장착 아이템에서의 장착('inven-use'와 함께 사용)
	 *
	 * 'money-up' - 금액 증가
	 * 'money-down' - 금액 감소
	 * 'money-gift' - 금액 선물
	 *
	 * 'item-gift' - 아이템 선물('inven-gift'와 함께 사용)
	 *
	 * 'ad-item-give' - 관리자 전용 아이템 주기
	 * 'ad-item-takeaway' - 관리자 전용 아이템 뺏기
	 *
	*******************************************************************************/
	if (StrEqual(process, "buy", false))
	{
		/*************************************************
		 *
		 * [아이템 구매]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분 준비
		 *
		 * [0] - 아이템 번호
		**************************/
		int iItemIdx = StringToInt(data);

		// 아이템 금액 확인
		int iItemMny = dds_eItem[iItemIdx][MONEY];

		/*************************
		 * 조건 및 환경 변수 확인
		**************************/
		/** 환경 변수 확인(유저단) **/
		// 

		/** 조건 확인 **/
		// 돈 부족
		if ((dds_iUserMoney[client] - iItemMny) < 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money nid", (iItemMny - dds_iUserMoney[client]), "global money");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 아이템 정보 삽입
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrI = CreateArray(8);
		hMakeErrI.Push(client);
		hMakeErrI.Push(2010);
		
		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"INSERT INTO `dds_user_item` (`idx`, `authid`, `ilidx`, `aplied`, `buydate`) VALUES (NULL, '%s', '%d', '0', '%s')", 
			sClient_AuthId, iItemIdx, GetTime());
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrI);

		/*************************
		 * 금액 정보 갱신
		**************************/
		char sSendParam[32];
		Format(sSendParam, sizeof(sSendParam), "%d||%d", 2011, iItemMny);
		System_DataProcess(client, "money-down", sSendParam);

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iItemIdx][NAME], sItemName, sizeof(sItemName));

		Format(sBuffer, sizeof(sBuffer), "%t", "system user buy", sCGName, sItemName, "global item");
		DDS_PrintToChat(client, sBuffer);
	}
	else if (StrEqual(process, "inven-use", false) || StrEqual(process, "curitem-use", false))
	{
		/*************************************************
		 *
		 * [인벤토리에서의 아이템 사용하기]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 데이터베이스 번호
		 * [1] - 아이템 번호
		**************************/
		char sTempStr[2][16];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iDBIdx = StringToInt(sTempStr[0]);
		int iItemIdx = StringToInt(sTempStr[1]);

		/*************************
		 * 기존 아이템 정보 갱신
		**************************/
		int iPrevItemIdx;
		// 기존에 장착한 아이템이 있으면 장착 해제 처리
		if (dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][ITEMIDX] > 0)
		{
			// 오류 검출 생성
			ArrayList hMakeErrIf = CreateArray(8);
			hMakeErrIf.Push(client);
			hMakeErrIf.Push(2012);

			// 쿼리 전송
			Format(sSendQuery, sizeof(sSendQuery), 
				"UPDATE `dds_user_item` SET `aplied` = '0' WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
				dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][DBIDX], sClient_AuthId, dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][ITEMIDX]);
			dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

			// 초기화
			iPrevItemIdx = dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][ITEMIDX];
			dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][DBIDX] = 0;
			dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][ITEMIDX] = 0;
		}

		/*************************
		 * 대상 아이템 정보 갱신
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIt = CreateArray(8);
		hMakeErrIt.Push(client);
		hMakeErrIt.Push(2013);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"UPDATE `dds_user_item` SET `aplied` = '1' WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
			iDBIdx, sClient_AuthId, iItemIdx);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIt);

		// 정보 갱신
		dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][DBIDX] = iDBIdx;
		dds_iUserAppliedItem[client][dds_eItem[iItemIdx][CATECODE]][ITEMIDX] = iItemIdx;

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];

		// 기존 아이템 출력
		if (iPrevItemIdx > 0)
		{
			SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iPrevItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
			SelectedGeoNameToString(client, dds_eItem[iPrevItemIdx][NAME], sItemName, sizeof(sItemName));

			Format(sBuffer, sizeof(sBuffer), "%t", "system user inven use prev", sCGName, sItemName, "global item");
			DDS_PrintToChat(client, sBuffer);
		}

		// 대상 아이템 출력
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iItemIdx][NAME], sItemName, sizeof(sItemName));

		Format(sBuffer, sizeof(sBuffer), "%t", "system user inven use after", sCGName, sItemName, "global item");
		DDS_PrintToChat(client, sBuffer);
	}
	else if (StrEqual(process, "inven-resell", false))
	{
		/*************************************************
		 *
		 * [인벤토리에서의 아이템 되팔기]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 데이터베이스 번호
		 * [1] - 아이템 번호
		**************************/
		char sTempStr[2][16];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iDBIdx = StringToInt(sTempStr[0]);
		int iItemIdx = StringToInt(sTempStr[1]);

		// 합할 금액 갱신 조건 확인
		int iItemMny = RoundToFloor(dds_eItem[iItemIdx][MONEY] * dds_hCV_ItemResellRatio.FloatValue);

		/*************************
		 * 기능 사용 여부
		**************************/
		if (!dds_hCV_SwitchResellItem.BoolValue)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "system user inven resell function");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 조건 및 환경 변수 확인
		**************************/
		/** 환경 변수 확인(유저단) **/

		/** 조건 확인 **/
		// int 변수 하나에 2147483647 을 넘길 수 없음
		if ((dds_iUserMoney[client] + iItemMny) > 2147400000)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money sobig");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 대상 아이템 정보 삭제
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(2020);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"DELETE FROM `dds_user_item` WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
			iDBIdx, sClient_AuthId, iItemIdx);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		/*************************
		 * 금액 정보 갱신
		**************************/
		char sSendParam[32];
		Format(sSendParam, sizeof(sSendParam), "%d||%d", 2021, iItemMny);
		System_DataProcess(client, "money-up", sSendParam);

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iItemIdx][NAME], sItemName, sizeof(sItemName));

		Format(sBuffer, sizeof(sBuffer), "%t", "system user inven resell", sCGName, sItemName, iItemMny, "global money", "global item");
		DDS_PrintToChat(client, sBuffer);
	}
	else if (StrEqual(process, "inven-gift", false) || StrEqual(process, "item-gift", false))
	{
		/*************************************************
		 *
		 * [인벤토리에서의 아이템 선물하기]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 데이터베이스 번호
		 * [1] - 아이템 번호
		 * [2] - 대상 클라이언트 유저ID
		**************************/
		char sTempStr[3][20];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iDBIdx = StringToInt(sTempStr[0]);
		int iItemIdx = StringToInt(sTempStr[1]);
		int iTargetUid = StringToInt(sTempStr[2]);

		/*************************
		 * 기능 사용 여부
		**************************/
		if (!dds_hCV_SwitchGiftItem.BoolValue)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "system user inven gift function");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 대상 클라이언트 검증
		**************************/
		int iTarget = GetClientOfUserId(iTargetUid);
		if (!IsClientInGame(iTarget))
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "system user inven gift tarerr");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 본인 아이템 정보 삭제
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(2016);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"DELETE FROM `dds_user_item` WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
			iDBIdx, sClient_AuthId, iItemIdx);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		/*************************
		 * 대상 아이템 정보 등록
		**************************/
		// 대상 클라이언트 고유번호 추출
		char sTargetAuthId[20];
		GetClientAuthId(iTarget, AuthId_SteamID64, sTargetAuthId, sizeof(sTargetAuthId));

		// 오류 검출 생성
		ArrayList hMakeErrIt = CreateArray(8);
		hMakeErrIt.Push(iTarget);
		hMakeErrIt.Push(2017);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"INSERT INTO `dds_user_item` (`idx`, `authid`, `ilidx`, `aplied`, `buydate`) VALUES (NULL, '%s', '%d', '0', '%s')", 
			sTargetAuthId, iItemIdx, GetTime());
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIt);

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iItemIdx][NAME], sItemName, sizeof(sItemName));

		// 클라이언트와 대상 클라이언트 이름 추출
		char sUsrName[2][32];
		GetClientName(client, sUsrName[0], 32);
		GetClientName(iTarget, sUsrName[1], 32);

		Format(sBuffer, sizeof(sBuffer), "%t", "system user inven gift send", sCGName, sItemName, sUsrName[1], "global item");
		DDS_PrintToChat(client, sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "system user inven gift take", sCGName, sItemName, sUsrName[0], "global item");
		DDS_PrintToChat(iTarget, sBuffer);
	}
	else if (StrEqual(process, "inven-drop", false))
	{
		/*************************************************
		 *
		 * [인벤토리에서의 아이템 버리기]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 데이터베이스 번호
		 * [1] - 아이템 번호
		**************************/
		char sTempStr[2][16];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iDBIdx = StringToInt(sTempStr[0]);
		int iItemIdx = StringToInt(sTempStr[1]);

		/*************************
		 * 대상 아이템 정보 삭제
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(2015);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"DELETE FROM `dds_user_item` WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
			iDBIdx, sClient_AuthId, iItemIdx);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iItemIdx][NAME], sItemName, sizeof(sItemName));

		Format(sBuffer, sizeof(sBuffer), "%t", "system user inven drop", sCGName, sItemName, "global item");
		DDS_PrintToChat(client, sBuffer);
	}
	else if (StrEqual(process, "curitem-cancel", false))
	{
		/*************************************************
		 *
		 * [내 장착 아이템에서의 장착 해제]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 아이템 종류 코드
		**************************/
		int iCGCode = StringToInt(data);

		/*************************
		 * 대상 아이템 정보 갱신
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(2014);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"UPDATE `dds_user_item` SET `aplied` = '0' WHERE `idx` = '%d' and `authid` = '%s' and `ilidx` = '%d'", 
			dds_iUserAppliedItem[client][iCGCode][DBIDX], sClient_AuthId, dds_iUserAppliedItem[client][iCGCode][ITEMIDX]);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		// 정보 갱신
		int iPrevItemIdx = dds_iUserAppliedItem[client][iCGCode][ITEMIDX];
		dds_iUserAppliedItem[client][iCGCode][DBIDX] = 0;
		dds_iUserAppliedItem[client][iCGCode][ITEMIDX] = 0;

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iPrevItemIdx][CATECODE]][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[iPrevItemIdx][NAME], sItemName, sizeof(sItemName));

		Format(sBuffer, sizeof(sBuffer), "%t", "system user curitem cancel", sCGName, sItemName, "global item");
		DDS_PrintToChat(client, sBuffer);
	}
	else if (StrEqual(process, "money-up", false))
	{
		/*************************************************
		 *
		 * [금액 증가]
		 *
		 * - 화면 출력 없음
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 오류 코드
		 * [1] - 증가할 금액
		**************************/
		char sTempStr[2][32];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iErrCode = StringToInt(sTempStr[0]);
		int iTarMoney = StringToInt(sTempStr[1]);

		/*************************
		 * 조건 및 환경 변수 확인
		**************************/
		/** 환경 변수 확인(유저단) **/

		/** 조건 확인 **/
		// int 변수 하나에 2147483647 을 넘길 수 없음
		if ((dds_iUserMoney[client] + iTarMoney) > 2147400000)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money sobig");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 금액 정보 갱신
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(iErrCode);
		
		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"UPDATE `dds_user_profile` SET `money` = `money` + '%d' WHERE `authid` = '%s'", 
			iTarMoney, sClient_AuthId);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		// 실제 금액 갱신
		dds_iUserMoney[client] += iTarMoney;
	}
	else if (StrEqual(process, "money-down", false))
	{
		/*************************************************
		 *
		 * [금액 감소]
		 *
		 * - 화면 출력 없음
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 오류 코드
		 * [1] - 감소할 금액
		**************************/
		char sTempStr[2][32];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iErrCode = StringToInt(sTempStr[0]);
		int iTarMoney = StringToInt(sTempStr[1]);

		/*************************
		 * 조건 및 환경 변수 확인
		**************************/
		/** 환경 변수 확인(유저단) **/
		// 

		/** 조건 확인 **/
		// 돈 부족
		if ((dds_iUserMoney[client] - iTarMoney) < 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money nid", (iTarMoney - dds_iUserMoney[client]), "global money");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 금액 정보 갱신
		**************************/
		// 오류 검출 생성
		ArrayList hMakeErrIf = CreateArray(8);
		hMakeErrIf.Push(client);
		hMakeErrIf.Push(iErrCode);
		
		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"UPDATE `dds_user_profile` SET `money` = `money` - '%d' WHERE `authid` = '%s'", 
			iTarMoney, sClient_AuthId);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrIf);

		// 실제 금액 갱신
		dds_iUserMoney[client] -= iTarMoney;
	}
	else if (StrEqual(process, "money-gift", false))
	{
		/*************************************************
		 *
		 * [금액 선물]
		 *
		**************************************************/

		/*************************
		 * 전달 파라메터 구분
		 *
		 * [0] - 증가할 금액
		 * [1] - 대상 클라이언트 유저ID
		**************************/
		char sTempStr[2][30];
		ExplodeString(data, "||", sTempStr, sizeof(sTempStr), sizeof(sTempStr[]));

		int iTarMoney = StringToInt(sTempStr[0]);
		int iTargetUid = StringToInt(sTempStr[1]);

		/*************************
		 * 기능 사용 여부
		**************************/
		if (!dds_hCV_SwitchGiftMoney.BoolValue)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "system user money gift function");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 대상 클라이언트 검증
		**************************/
		int iTarget = GetClientOfUserId(iTargetUid);
		if (!IsClientInGame(iTarget))
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "system user money gift tarerr");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 조건 및 환경 변수 확인
		**************************/
		/** 환경 변수 확인(유저단) **/
		// 

		/** 조건 확인 **/
		// 본인 돈 부족
		if ((dds_iUserMoney[client] - iTarMoney) < 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money nid", (iTarMoney - dds_iUserMoney[client]), "global money");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		// int 변수 하나에 2147483647 을 넘길 수 없음
		if ((dds_iUserMoney[iTarget] + iTarMoney) > 2147400000)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "error money sobig");
			DDS_PrintToChat(client, sBuffer);
			return;
		}

		/*************************
		 * 본인 금액 정보 갱신
		**************************/
		char sSendParam[32];
		Format(sSendParam, sizeof(sSendParam), "%d||%d", 2018, iTarMoney);
		System_DataProcess(client, "money-down", sSendParam);

		/*************************
		 * 대상 금액 정보 갱신
		**************************/
		// 대상 클라이언트 고유번호 추출
		char sTargetAuthId[20];
		GetClientAuthId(iTarget, AuthId_SteamID64, sTargetAuthId, sizeof(sTargetAuthId));

		// 갱신
		Format(sSendParam, sizeof(sSendParam), "%d||%d", 2019, iTarMoney);
		System_DataProcess(iTarget, "money-up", sSendParam);

		/*************************
		 * 화면 출력
		**************************/
		// 클라이언트와 대상 클라이언트 이름 추출
		char sUsrName[2][32];
		GetClientName(client, sUsrName[0], 32);
		GetClientName(iTarget, sUsrName[1], 32);

		Format(sBuffer, sizeof(sBuffer), "%t", "system user money gift send", iTarMoney, "global money", sUsrName[1]);
		DDS_PrintToChat(client, sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "system user money gift take", iTarMoney, "global money", sUsrName[0]);
		DDS_PrintToChat(iTarget, sBuffer);
	}
}


/**
 * LOG :: 오류코드 구분 및 로그 작성
 *
 * @param client			클라이언트 인덱스
 * @param errcode			오류 코드
 * @param errordec			오류 원인
 */
public void Log_CodeError(int client, int errcode, const char[] errordec)
{
	char usrauth[20];

	// 실제 클라이언트 구분 후 고유번호 추출
	if (client > 0)
	{
		if (IsClientAuthorized(client))
			GetClientAuthId(client, AuthId_SteamID64, usrauth, sizeof(usrauth));
	}

	// 클라이언트와 서버 구분하여 접두 메세지 설정
	char sDetOutput[512];
	char sOutput[512];
	char sPrefix[128];
	char sErrDesc[1024];

	if (client > 0) // 클라이언트
	{
		Format(sPrefix, sizeof(sPrefix), "[Error :: ID %d]", errcode);
		if (strlen(errordec) > 0) Format(sErrDesc, sizeof(sErrDesc), "[Error Desc :: ID %d] %s", errcode, errordec);
	}
	else if (client == 0) // 서버
	{
		Format(sPrefix, sizeof(sPrefix), "[%t :: ID %d]", "error occurred", errcode);
		if (strlen(errordec) > 0) Format(sErrDesc, sizeof(sErrDesc), "[%t :: ID %d] %s", "error desc", errcode, errordec);
	}

	Format(sDetOutput, sizeof(sDetOutput), "%s", sPrefix);
	Format(sOutput, sizeof(sOutput), "%s", sPrefix);

	// 오류코드 구분
	switch (errcode)
	{
		case 1000:
		{
			// SQL 데이터베이스 연결 실패
			Format(sDetOutput, sizeof(sDetOutput), "%s Connecting Database is Failure!", sDetOutput);
		}
		case 1001:
		{
			// SQL 데이터베이스 핸들 전달 실패
			Format(sDetOutput, sizeof(sDetOutput), "%s Database Handle is null!", sDetOutput);
		}
		case 1002:
		{
			// SQL 데이터베이스 초기화 시 아이템 카테고리 로드
			Format(sDetOutput, sizeof(sDetOutput), "%s Retriving Item Category DB is Failure!", sDetOutput);
		}
		case 1003:
		{
			// SQL 데이터베이스 초기화 시 아이템 목록 로드
			Format(sDetOutput, sizeof(sDetOutput), "%s Retriving Item List DB is Failure!", sDetOutput);
		}
		case 1010:
		{
			// 유저가 접속하여 정보를 로드할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile load");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retriving User Profile DB is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1011:
		{
			// 유저 체크 후 레코드가 없어 레코드를 만들 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile make");
			Format(sDetOutput, sizeof(sDetOutput), "%s Making User Profile is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1012:
		{
			// 유저 체크 후 레코드가 있어 정보를 갱신할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile cnupdate");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Profile is Failure! (C&U) (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1013:
		{
			// 유저가 서버로부터 나가면서 갱신 처리할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile dnupdate");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Profile is Failure! (D&U) (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1014:
		{
			// 유저 체크하면서 프로필 목록이 잘못되었을 경우
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile invalid");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retrived User Profile DB is invalid. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1015:
		{
			// 유저 체크하면서 유저 장착 아이템 목록이 잘못되었을 경우
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usritem applied");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retrived User Item DB is invalid. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1016:
		{
			// 유저 체크하면서 유저 아이템 설정 상태가 잘못되었을 경우
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrsetting load");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retrived User Setting DB is invalid. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1017:
		{
			// 유저 체크 후 레코드가 없어 설정 정보 레코드를 만들 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrprofile make setting");
			Format(sDetOutput, sizeof(sDetOutput), "%s Making User Setting is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1020:
		{
			// 유저가 내 장착 아이템 종류 메뉴를 열었을 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usritem curitem");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retriving User Item DB is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1021:
		{
			// 유저가 내 인벤토리 세부 메뉴를 열었을 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usritem inventory");
			Format(sDetOutput, sizeof(sDetOutput), "%s Retriving User Item DB is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 1022:
		{
			// 유저가 아이템 활성 상태를 변경하였을 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql usrsetting set");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Setting DB is Failure! (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2010:
		{
			// [아이템 처리 시스템] 아이템을 구매할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc buy");
			Format(sDetOutput, sizeof(sDetOutput), "%s Inserting User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2011:
		{
			// [아이템 처리 시스템] 아이템을 구매할 때 금액 갱신
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc buy money");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User's Money is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2012:
		{
			// [아이템 처리 시스템] 내 인벤토리에서 아이템을 장착하면서 기존 아이템 장착 해제할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven use prev");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2013:
		{
			// [아이템 처리 시스템] 내 인벤토리에서 아이템을 장착하면서 대상 아이템 장착할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven use after");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2014:
		{
			// [아이템 처리 시스템] 내 장착 아이템에서 아이템을 장착 해제시킬 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc curitem cancel");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2015:
		{
			// [아이템 처리 시스템] 내 인벤토리에서 아이템을 버릴 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven drop");
			Format(sDetOutput, sizeof(sDetOutput), "%s Deleting User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2016:
		{
			// [아이템 처리 시스템] 내 인벤토리에서 아이템을 선물할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven gift");
			Format(sDetOutput, sizeof(sDetOutput), "%s Deleting User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2017:
		{
			// [아이템 처리 시스템] 내 인벤토리를 이용하여 대상이 아이템을 선물받을 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven gift target");
			Format(sDetOutput, sizeof(sDetOutput), "%s Inserting User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2018:
		{
			// [아이템 처리 시스템] 금액 선물을 할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc money gift");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Money is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2019:
		{
			// [아이템 처리 시스템] 금액 선물을 이용하여 대상이 금액을 선물받을 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc money gift target");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Money is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2020:
		{
			// [아이템 처리 시스템] 인벤토리에서 아이템을 되팔 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven resell");
			Format(sDetOutput, sizeof(sDetOutput), "%s Deleting User Item is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2021:
		{
			// [아이템 처리 시스템] 인벤토리에서 아이템을 되팔으면서 금액을 갱신할 때
			Format(sOutput, sizeof(sOutput), "%s %t", sOutput, "error sql itemproc inven resell money");
			Format(sDetOutput, sizeof(sDetOutput), "%s Updating User Money is Failure. (AuthID: %s)", sDetOutput, usrauth);
		}
		case 2022:
		{
			// 
		}
	}

	// 클라이언트와 서버 구분하여 로그 출력
	if (client > 0) // 클라이언트
	{
		// 클라이언트 메세지 전송
		if (IsClientInGame(client))
		{
			DDS_PrintToChat(client, sOutput);
			if (strlen(sErrDesc) > 0) DDS_PrintToChat(client, sErrDesc);
		}

		// 서버 메세지 전송
		DDS_PrintToServer("%s (client: %N)", sDetOutput, client);
		if (strlen(sErrDesc) > 0) DDS_PrintToServer("%s (client: %N)", sErrDesc, client);

		// 로그 파일 작성
		LogToFile(dds_sPluginLogFile, "%s (client: %N)", sDetOutput, client);
		if (strlen(sErrDesc) > 0) LogToFile(dds_sPluginLogFile, "%s (client: %N)", sErrDesc, client);
	}
	else if (client == 0) // 서버
	{
		// 서버 메세지 전송
		DDS_PrintToServer(sDetOutput);
		if (strlen(sErrDesc) > 0) DDS_PrintToServer(sErrDesc);

		// 로그 파일 작성
		LogToFile(dds_sPluginLogFile, "%s (Server)", sDetOutput);
		if (strlen(sErrDesc) > 0) LogToFile(dds_sPluginLogFile, "%s (Server)", sErrDesc);
	}
}

/**
 * LOG :: 데이터 로그 작성
 *
 * @param client			클라이언트 인덱스
 * @param action			행동 구분
 * @param data				추가 파라메터
 */
public void Log_Data(int client, const char[] action, const char[] data)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	// ConVar 설정 확인
	if (!dds_hCV_SwtichLogData.BoolValue)	return;

	/*******************************
	 * 설정 준비
	********************************/
	// 실제 클라이언트 구분 후 고유번호 추출
	char sUsrAuthId[20];
	if (client > 0)
	{
		if (IsClientAuthorized(client))
			GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));
	}

	// 출력 설정
	char sOutput[512];

	/******************************************************************************
	 * -----------------------------------
	 * 'action' 파라메터 종류 별 나열
	 * -----------------------------------
	 *
	 * 'game-connect' - 게임 내에 들어왔을 때
	 * 'game-disconnect' - 게임 밖으로 나갔을 때
	 * 'item-buy' - 메인 메뉴에서 아이템을 구매할 때
	 * 'item-use' - 아이템을 장착하였을 때
	 * 'item-cancel' - 아이템을 장착 해제하였을 때
	 * 'item-resell' - 아이템을 되팔았을 때
	 * 'item-gift' - 아이템을 선물하였을 때
	 * 'item-drop' - 아이템을 버렸을 때
	 * 'money-up' - 금액이 증가될 때
	 * 'money-down' - 금액이 내려갈 때
	 * 'money-gift' - 금액을 선물할 때
	 * 'ad-item-give' - 관리자가 아이템을 줄 때
	 * 'ad-item-seize' - 관리자가 아이템을 빼앗을 때
	 *
	*******************************************************************************/
	if (StrEqual(action, "game-connect", false))
	{
		// 게임 내에 들어왔을 때
	}
	else if (StrEqual(action, "game-disconnect", false))
	{
		// 게임 밖으로 나갔을 때
	}
	else if (StrEqual(action, "buy", false))
	{
		// 메인 메뉴에서 아이템을 구매할 때
	}
	else if (StrEqual(action, "money-gift", false))
	{
		// 금액을 선물할 때
	}

	/*******************************
	 * 로그 생성
	********************************/
	if (client > 0)
	{
		// 
	}
}


/**
 * SQL :: 초기화 및 SQL 데이터베이스에 있는 데이터 로드
 */
public void SQL_DDSDatabaseInit()
{
	/** 초기화 **/
	// 서버
	Init_ServerData();
	// 유저
	Init_UserData(0, 1);

	/** 데이터 로드 **/
	char sSendQuery[512];

	// 아이템 카테고리 로드
	Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_item_category` WHERE `status` = '1' ORDER BY `orderidx` ASC");
	dds_hSQLDatabase.Query(SQL_LoadItemCategory, sSendQuery, 0, DBPrio_High);
	// 아이템 목록 로드
	Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_item_list` WHERE `status` = '1' ORDER BY `ilidx` ASC");
	dds_hSQLDatabase.Query(SQL_LoadItemList, sSendQuery, 0, DBPrio_High);
}


/**
 * 메뉴 :: 메인 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param args				기타
*/
public Action:Menu_Main(int client, int args)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Continue;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlMain);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n ", "menu common title");
	mMain.SetTitle(buffer);

	// '내 프로필'
	Format(buffer, sizeof(buffer), "%t", "menu main myprofile");
	mMain.AddItem("1", buffer);
	// '내 장착 아이템'
	Format(buffer, sizeof(buffer), "%t", "menu main mycuritem");
	mMain.AddItem("2", buffer);
	// '내 인벤토리'
	Format(buffer, sizeof(buffer), "%t", "menu main myinven");
	mMain.AddItem("3", buffer);
	// '아이템 구매'
	Format(buffer, sizeof(buffer), "%t", "menu main buyitem");
	mMain.AddItem("4", buffer);
	// '설정'
	Format(buffer, sizeof(buffer), "%t\n ", "menu main setting");
	mMain.AddItem("5", buffer);
	// '플러그인 정보'
	Format(buffer, sizeof(buffer), "%t", "menu main plugininfo");
	mMain.AddItem("9", buffer);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);

	return Plugin_Continue;
}

/**
 * 메뉴 :: 프로필 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_Profile(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlProfile);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main myprofile");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 필요 정보
	char sUsrName[32];
	char sUsrAuthId[20];

	GetClientName(client, sUsrName, sizeof(sUsrName));
	GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

	Format(buffer, sizeof(buffer), 
		"%t\n \n%t: %s\n%t: %s\n%t: %d", 
		"menu myprofile introduce", "global nickname", sUsrName, "global authid", sUsrAuthId, "global money", dds_iUserMoney[client]);
	mMain.AddItem("1", buffer, ITEMDRAW_DISABLED);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 내 장착 아이템 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_CurItem(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlCurItem);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main mycuritem");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 정보 작성
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		// '전체' 통과
		if (i == 0)	continue;

		// 번호를 문자열로 치환
		char sTempIdx[4];
		IntToString(dds_eItemCategoryList[i][CODE], sTempIdx, sizeof(sTempIdx));

		// 클라이언트 국가에 따른 아이템과 종류 이름 추출
		char sCGName[16];
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));
		SelectedGeoNameToString(client, dds_eItem[dds_iUserAppliedItem[client][i][ITEMIDX]][NAME], sItemName, sizeof(sItemName));

		// 장착되어 있지 않으면 '없음' 처리
		if (dds_iUserAppliedItem[client][i][ITEMIDX] == 0) Format(sItemName, sizeof(sItemName), "%t", "global none");

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "%t %s %t: %s", "menu mycuritem applied", sCGName, "global item", sItemName);
		mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 My CurItem Menu ~ CG (ID: %d, CateName: %s, ItemName: %s, Count: %d)", i, sCGName, sItemName, count);
		#endif
	}

	// 아이템 종류가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 내 장착 아이템 메뉴-종류 출력
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param data					기타(0 - 클라이언트 인덱스, 1 - 아이템 종류 코드)
 */
public void Menu_CurItem_CateIn(Database db, DBResultSet results, const char[] error, any data)
{
	/******
	 * @param data				Handle / ArrayList
	 * 					0 - 클라이언트 인덱스(int), 1 - 아이템 종류 코드(int)
	 ******/
	// 타입 변환(*!*핸들 누수가 있는지?)
	ArrayList hData = view_as<ArrayList>(data);

	int client = hData.Get(0);
	int catecode = hData.Get(1);

	delete hData;

	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(0, 1020, error);
		return;
	}

	// 클라이언트 국가에 따른 아이템 종류 이름 추출
	char sCGName[16];
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		// '전체' 항목은 제외
		if (i == 0)	continue;

		// 선택한 아이템 종류 코드와 맞지 않는 경우는 제외
		if (catecode != dds_eItemCategoryList[i][CODE])	continue;

		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));
		break;
	}

	// 메뉴 및 제목 설정
	char buffer[256];
	Menu mMain = new Menu(Main_hdlCurItem_CateIn);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%s\n ", "menu common title", "menu common curpos", "menu main mycuritem", sCGName);
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 아이템 정보
		int iTmpDbIdx = results.FetchInt(0);
		int iTmpItIdx = results.FetchInt(2);
		int iTmpItAp = results.FetchInt(3);

		// 0번은 있을 수 없지만 혹시 모르므로 제외
		if (iTmpItIdx == 0)	continue;

		// '전체' 항목이 아니면서 선택한 아이템 종류가 아닌 아이템은 제외
		if ((catecode != dds_eItem[iTmpItIdx][CATECODE]) && catecode != 0)	continue;

		// 체크되는 아이템의 아이템 종류가 등록되어 있는 아이템 종류가 없는 경우는 제외
		// 이유: 유저가 가지고 있는 아이템 중 그에 맞는 아이템 종류가 활성화되지 않은 아이템 종류인 경우를 피하려는 것 때문
		bool bInCate = false;
		for (int i = 0; i <= dds_iItemCategoryCount; i++)
		{
			// '전체'는 제외
			if (i == 0)	continue;

			// 유효한지 파악
			if (dds_eItem[iTmpItIdx][CATECODE] == dds_eItemCategoryList[i][CODE])
			{
				bInCate = true;
				break;
			}
		}
		if (!bInCate)	continue;

		// 현재 장착하고 있으면 '장착 해제' 메뉴 생성
		if (count == 0)
		{
			if (dds_iUserAppliedItem[client][catecode][ITEMIDX] > 0)
			{
				// 번호를 문자열로 치환
				char sTempIdx[16];
				Format(sTempIdx, sizeof(sTempIdx), "%d||%d||%d", catecode, catecode, 0);

				// 메뉴 등록
				Format(buffer, sizeof(buffer), "%t", "menu mycuritem apply cancel");
				mMain.AddItem(sTempIdx, buffer);
			}
		}

		// 번호를 문자열로 치환
		char sTempIdx[16];
		Format(sTempIdx, sizeof(sTempIdx), "%d||%d||%d", iTmpDbIdx, iTmpItIdx, 1);

		// 클라이언트 국가에 따른 아이템 종류 이름 추출(아이템 자체에서 판단)
		char sItemCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iTmpItIdx][CATECODE]][NAME], sItemCGName, sizeof(sItemCGName));

		// 클라이언트 국가에 따른 아이템 이름 추출
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItem[iTmpItIdx][NAME], sItemName, sizeof(sItemName));

		// 아이템이 장착되어 있는지 작성
		char sApStr[16];
		Format(sApStr, sizeof(sApStr), "");
		if (iTmpItAp > 0)
			Format(sApStr, sizeof(sApStr), " - %t", "global applied");

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "[%s] %s%s", sItemCGName, sItemName, sApStr);
		// 아이템을 장착하고 있는건 사용할 수 없게 처리
		if (iTmpItAp > 0)
			mMain.AddItem(sTempIdx, buffer, ITEMDRAW_DISABLED);
		else
			mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Inven-CateIn Menu ~ CG (CateCode: %d, ItemName: %s, ItemIdx: %d, Count: %d)", catecode, sItemName, iTmpItIdx, count);
		#endif
	}

	// 아이템이 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 내 인벤토리 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param args				기타
*/
public Action:Menu_Inven(int client, int args)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Continue;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlInven);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main myinven");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 정보 작성
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		// 번호를 문자열로 치환
		char sTempIdx[4];
		IntToString(dds_eItemCategoryList[i][CODE], sTempIdx, sizeof(sTempIdx));

		// 클라이언트 국가에 따른 아이템 종류 이름 추출
		char sCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "%s %t", sCGName, "global item");
		mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 My Inven Menu ~ CG (ID: %d, CateName: %s, Count: %d)", i, sCGName, count);
		#endif
	}

	// 아이템 종류가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);

	return Plugin_Continue;
}

/**
 * 메뉴 :: 내 인벤토리-종류 세부 메뉴 출력
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param data					기타(0 - 클라이언트 인덱스, 1 - 아이템 종류 코드)
 */
public void Menu_Inven_CateIn(Database db, DBResultSet results, const char[] error, any data)
{
	/******
	 * @param data				Handle / ArrayList
	 * 					0 - 클라이언트 인덱스(int), 1 - 아이템 종류 코드(int)
	 ******/
	// 타입 변환(*!*핸들 누수가 있는지?)
	ArrayList hData = view_as<ArrayList>(data);

	int client = hData.Get(0);
	int catecode = hData.Get(1);

	delete hData;

	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(0, 1021, error);
		return;
	}

	// 클라이언트 국가에 따른 아이템 종류 이름 추출
	char sCGName[16];
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		if (catecode != dds_eItemCategoryList[i][CODE])	continue;

		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));
		break;
	}

	// 메뉴 및 제목 설정
	char buffer[256];
	Menu mMain = new Menu(Main_hdlInven_CateIn);

	Format(buffer, sizeof(buffer), "%t\n%t: %t-%s\n ", "menu common title", "menu common curpos", "menu main myinven", sCGName);
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 아이템 정보
		int iTmpDbIdx = results.FetchInt(0);
		int iTmpItIdx = results.FetchInt(2);
		int iTmpItAp = results.FetchInt(3);

		// 0번은 있을 수 없지만 혹시 모르므로 제외
		if (iTmpItIdx == 0)	continue;

		// '전체' 항목이 아니면서 선택한 아이템 종류가 아닌 아이템은 제외
		if ((catecode != dds_eItem[iTmpItIdx][CATECODE]) && catecode != 0)	continue;

		// 체크되는 아이템의 아이템 종류가 등록되어 있는 아이템 종류가 없는 경우는 제외
		// 이유: 유저가 가지고 있는 아이템 중 그에 맞는 아이템 종류가 활성화되지 않은 아이템 종류인 경우를 피하려는 것 때문
		bool bInCate = false;
		for (int i = 0; i <= dds_iItemCategoryCount; i++)
		{
			// '전체'는 제외
			if (i == 0)	continue;

			// 유효한지 파악
			if (dds_eItem[iTmpItIdx][CATECODE] == dds_eItemCategoryList[i][CODE])
			{
				bInCate = true;
				break;
			}
		}
		if (!bInCate)	continue;

		// 번호를 문자열로 치환
		char sTempIdx[16];
		Format(sTempIdx, sizeof(sTempIdx), "%d||%d", iTmpDbIdx, iTmpItIdx);

		// 클라이언트 국가에 따른 아이템 종류 이름 추출(아이템 자체에서 판단)
		char sItemCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[iTmpItIdx][CATECODE]][NAME], sItemCGName, sizeof(sItemCGName));

		// 클라이언트 국가에 따른 아이템 이름 추출
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItem[iTmpItIdx][NAME], sItemName, sizeof(sItemName));

		// 아이템이 장착되어 있는지 작성
		char sApStr[16];
		Format(sApStr, sizeof(sApStr), "");
		if (iTmpItAp > 0)
			Format(sApStr, sizeof(sApStr), " - %t", "global applied");

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "[%s] %s%s", sItemCGName, sItemName, sApStr);
		// 아이템을 장착하고 있는건 사용할 수 없게 처리
		if (iTmpItAp > 0)
			mMain.AddItem(sTempIdx, buffer, ITEMDRAW_DISABLED);
		else
			mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Inven-CateIn Menu ~ CG (CateCode: %d, ItemName: %s, ItemIdx: %d, Count: %d)", catecode, sItemName, iTmpItIdx, count);
		#endif
	}

	// 아이템이 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 내 인벤토리-정보 세부 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param dataidx			데이터베이스 인덱스 번호
 * @param itemidx			아이템 번호
*/
public Menu_Inven_ItemDetail(int client, int dataidx, int itemidx)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlInven_ItemDetail);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%t\n ", "menu common title", "menu common curpos", "menu main myinven", "menu main myinven check");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 전달 파라메터 기초 생성
	char sParam[16];

	// 클라이언트 국가에 따른 아이템 종류 이름 추출
	char sItemName[32];
	SelectedGeoNameToString(client, dds_eItem[itemidx][NAME], sItemName, sizeof(sItemName));

	// 메뉴 아이템 등록
	Format(buffer, sizeof(buffer), "%t", "global use");
	Format(sParam, sizeof(sParam), "%d||%d||%d", dataidx, itemidx, 1);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t", "global resell");
	Format(sParam, sizeof(sParam), "%d||%d||%d", dataidx, itemidx, 2);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t", "global gift");
	Format(sParam, sizeof(sParam), "%d||%d||%d", dataidx, itemidx, 3);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t\n ", "global drop");
	Format(sParam, sizeof(sParam), "%d||%d||%d", dataidx, itemidx, 4);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t\n \n%t: %s\n%t: %d", "menu myinven info", "global name", sItemName, "global money", dds_eItem[itemidx][MONEY]);
	mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);

	#if defined _DEBUG_
	DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Inven-ItemDetail Menu ~ CG (ItemIdx: %d, ItemName: %s)", itemidx, sItemName);
	#endif

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 아이템 구매 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_BuyItem(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlBuyItem);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main buyitem");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 정보 작성
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		// 번호를 문자열로 치환
		char sTempIdx[4];
		IntToString(dds_eItemCategoryList[i][CODE], sTempIdx, sizeof(sTempIdx));

		// 클라이언트 국가에 따른 아이템 종류 이름 추출
		char sCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "%s %t", sCGName, "global item");
		mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Buy Item Menu ~ CG (ID: %d, CateName: %s, Count: %d)", i, sCGName, count);
		#endif
	}

	// 아이템 종류가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 아이템 구매-종류 세부 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param catecode			아이템 종류 코드
*/
public Menu_BuyItem_CateIn(int client, int catecode)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlBuyItem_CateIn);

	// 클라이언트 국가에 따른 아이템 종류 이름 추출
	char sCGName[16];
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		if (catecode != dds_eItemCategoryList[i][CODE])	continue;

		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));
		break;
	}

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%s\n ", "menu common title", "menu common curpos", "menu main buyitem", sCGName);
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 정보 작성
	for (int i = 0; i <= dds_iItemCount; i++)
	{
		// 0번은 제외
		if (i == 0)	continue;

		// '전체' 항목이 아니면서 선택한 아이템 종류가 아닌 아이템은 제외
		if ((catecode != dds_eItem[i][CATECODE]) && catecode != 0)	continue;

		// 체크되는 아이템의 아이템 종류가 등록되어 있는 아이템 종류가 없는 경우는 제외
		// 이유: 등록되어 있는 아이템 중 그에 맞는 아이템 종류가 활성화되지 않은 아이템 종류인 경우를 피하려는 것 때문
		bool bInCate = false;
		for (int k = 0; k <= dds_iItemCategoryCount; k++)
		{
			// '전체'는 제외
			if (k == 0)	continue;

			// 유효한지 파악
			if (dds_eItem[i][CATECODE] == dds_eItemCategoryList[k][CODE])
			{
				bInCate = true;
				break;
			}
		}
		if (!bInCate)	continue;

		// 번호를 문자열로 치환
		char sTempIdx[4];
		IntToString(i, sTempIdx, sizeof(sTempIdx));

		// 클라이언트 국가에 따른 아이템 종류 이름 추출(아이템 자체에서 판단)
		char sItemCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[dds_eItem[i][CATECODE]][NAME], sItemCGName, sizeof(sItemCGName));

		// 클라이언트 국가에 따른 아이템 이름 추출
		char sItemName[32];
		SelectedGeoNameToString(client, dds_eItem[i][NAME], sItemName, sizeof(sItemName));

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "[%s] %s - %d %t", sItemCGName, sItemName, dds_eItem[i][MONEY], "global money");
		mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Buy Item-CateIn Menu ~ CG (CateCode: %d, ItemName: %s, ItemIdx: %d, Count: %d)", catecode, sItemName, i, count);
		#endif
	}

	// 아이템 종류가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 아이템 구매-정보 세부 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param itemidx			아이템 번호
*/
public Menu_BuyItem_ItemDetail(int client, int itemidx)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlBuyItem_ItemDetail);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%t\n ", "menu common title", "menu common curpos", "menu main buyitem", "menu main buyitem check");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 전달 파라메터 기초 생성
	char sParam[16];

	// 클라이언트 국가에 따른 아이템 종류 이름 추출
	char sItemName[32];
	SelectedGeoNameToString(client, dds_eItem[itemidx][NAME], sItemName, sizeof(sItemName));

	// 메뉴 아이템 등록
	Format(buffer, sizeof(buffer), "%t", "global confirm");
	Format(sParam, sizeof(sParam), "%d||%d||%d", itemidx, dds_eItem[itemidx][CATECODE], 1);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t\n ", "global cancel");
	Format(sParam, sizeof(sParam), "%d||%d||%d", itemidx, dds_eItem[itemidx][CATECODE], 2);
	mMain.AddItem(sParam, buffer);
	Format(buffer, sizeof(buffer), "%t\n \n%t: %s\n%t: %d", "menu buyitem willbuy", "global name", sItemName, "global money", dds_eItem[itemidx][MONEY]);
	mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);

	#if defined _DEBUG_
	DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Buy Item-ItemDetail Menu ~ CG (ItemIdx: %d, ItemName: %s)", itemidx, sItemName);
	#endif

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 설정 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_Setting(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlSetting);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main setting");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 메뉴 아이템 등록
	Format(buffer, sizeof(buffer), "%t", "menu setting system");
	mMain.AddItem("1", buffer);
	Format(buffer, sizeof(buffer), "%t", "menu setting item");
	mMain.AddItem("2", buffer);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 설정-시스템 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_Setting_System(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlSetting_System);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu setting system");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 메뉴 아이템 등록
	Format(buffer, sizeof(buffer), "%t", "global nothing");
	mMain.AddItem("1", buffer, ITEMDRAW_DISABLED);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 설정-아이템 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_Setting_Item(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlSetting_Item);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu setting item");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 갯수 파악
	int count;

	// 정보 작성
	for (int i = 0; i <= dds_iItemCategoryCount; i++)
	{
		// '전체' 통과
		if (i == 0)	continue;
		
		// 번호를 문자열로 치환
		char sTempIdx[4];
		IntToString(i, sTempIdx, sizeof(sTempIdx));

		// 클라이언트 국가에 따른 아이템 종류 이름 추출
		char sCGName[16];
		SelectedGeoNameToString(client, dds_eItemCategoryList[i][NAME], sCGName, sizeof(sCGName));

		// 활성화 판단
		char sStatus[16];
		if (dds_eUserItemCGStatus[client][i][VALUE])
			Format(sStatus, sizeof(sStatus), "%t", "menu setting status active");
		else
			Format(sStatus, sizeof(sStatus), "%t", "menu setting status inactive");

		// 메뉴 아이템 등록
		Format(buffer, sizeof(buffer), "%s: %s", sCGName, sStatus);
		mMain.AddItem(sTempIdx, buffer);

		// 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToChat(client, "\x05:: DEBUG ::\x01 Setting-Item Menu ~ CG (CateCode: %d, CateName: %s, Count: %d, Value: %s)", dds_eItemCategoryList[i][CODE], sCGName, count, sStatus);
		#endif
	}

	// 아이템 종류가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 플러그인 정보 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_PluginInfo(int client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlPluginInfo);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu main plugininfo");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 메뉴 아이템 등록
	Format(buffer, sizeof(buffer), "%t", "menu plugininfo cmd");
	mMain.AddItem("1", buffer);
	Format(buffer, sizeof(buffer), "%t", "menu plugininfo author");
	mMain.AddItem("2", buffer);
	Format(buffer, sizeof(buffer), "%t", "menu plugininfo license");
	mMain.AddItem("3", buffer);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 플러그인 정보-세부 메뉴 출력
 *
 * @param client			클라이언트 인덱스
*/
public Menu_PluginInfo_Detail(int client, int select)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlPluginInfo_Detail);

	// 세부 제목 설정
	char sDetailTitle[32];
	switch (select)
	{
		case 1:
		{
			Format(sDetailTitle, sizeof(sDetailTitle), "%t", "menu plugininfo cmd");
		}
		case 2:
		{
			Format(sDetailTitle, sizeof(sDetailTitle), "%t", "menu plugininfo author");
		}
		case 3:
		{
			Format(sDetailTitle, sizeof(sDetailTitle), "%t", "menu plugininfo license");
		}
	}

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %s\n ", "menu common title", "menu common curpos", sDetailTitle);
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 메뉴 아이템 등록
	switch (select)
	{
		case 1:
		{
			// 명령어 정보
			Format(buffer, sizeof(buffer), "!%s: %t", DDS_ENV_USER_MAINMENU, "menu plugininfo cmd desc main");
			mMain.AddItem("1", buffer);
		}
		case 2:
		{
			// 개발자 정보
			Format(buffer, sizeof(buffer), "%s - v%s\n ", DDS_ENV_CORE_NAME, DDS_ENV_CORE_VERSION);
			mMain.AddItem("1", buffer);
			Format(buffer, sizeof(buffer), "Made By. Karsei\n(http://karsei.pe.kr)");
			mMain.AddItem("2", buffer);
		}
		case 3:
		{
			// 저작권 정보
			Format(buffer, sizeof(buffer), "GNU General Public License 3 (GNU GPL v3)\n ");
			mMain.AddItem("1", buffer);
			Format(buffer, sizeof(buffer), "%t: http://www.gnu.org/licenses/", "menu plugininfo license detail");
			mMain.AddItem("2", buffer);
		}
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 아이템 선물-대상 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param data				추가 파라메터
*/
public Menu_ItemGift(int client, const char[] data)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlItemGift);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%t\n ", "menu common title", "menu common curpos", "menu itemgift", "global target");
	mMain.SetTitle(buffer);

	// 전달 파라메터 등록
	char sSendParam[8];

	// 갯수 파악
	int count;

	// 메뉴 아이템 등록
	for (int i = 0; i < MaxClients; i++)
	{
		// 서버는 통과
		if (i == 0)	continue;

		// 게임 내에 없으면 통과
		if (!IsClientInGame(i))	continue;

		// 봇이면 통과
		if (IsFakeClient(i))	continue;

		// 인증이 되어 있지 않으면 통과
		if (!IsClientAuthorized(i))	continue;

		// 본인은 통과
		if (i == client)	continue;

		Format(buffer, sizeof(buffer), "%N", i);
		Format(sSendParam, sizeof(sSendParam), "%d||%s", GetClientUserId(i), data);
		mMain.AddItem(sSendParam, buffer);

		// 갯수 증가
		count++;
	}

	// 유저가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메뉴 :: 관리자 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param args				기타
*/
public Action:Menu_Admin(int client, int args)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Continue;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlAdmin);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t\n ", "menu common title", "menu common curpos", "menu admin");
	mMain.SetTitle(buffer);

	// '금액 주기'
	Format(buffer, sizeof(buffer), "%t", "menu admin givemoney");
	mMain.AddItem("1", buffer);
	// '금액 뺏기'
	Format(buffer, sizeof(buffer), "%t", "menu admin seizemoney");
	mMain.AddItem("2", buffer);
	// '아이템 주기'
	Format(buffer, sizeof(buffer), "%t", "menu admin giveitem");
	mMain.AddItem("3", buffer);
	// '아이템 뺏기'
	Format(buffer, sizeof(buffer), "%t", "menu admin seizeitem");
	mMain.AddItem("4", buffer);

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);

	return Plugin_Continue;
}

/**
 * 메뉴 :: 관리자 아이템-대상 메뉴 출력
 *
 * @param client			클라이언트 인덱스
 * @param action			행동 구분
*/
public Menu_Admin_Item(int client, const char[] action)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return;

	char buffer[256];
	Menu mMain = new Menu(Main_hdlAdmin_Item);

	// 제목 설정
	Format(buffer, sizeof(buffer), "%t\n%t: %t-%t\n ", "menu common title", "menu common curpos", "menu admin", "global target");
	mMain.SetTitle(buffer);
	mMain.ExitBackButton = true;

	// 전달 파라메터 등록
	char sSendParam[52];

	// 갯수 파악
	int count;

	// 메뉴 아이템 등록
	for (int i = 0; i < MaxClients; i++)
	{
		// 서버는 통과
		if (i == 0)	continue;

		// 게임 내에 없으면 통과
		if (!IsClientInGame(i))	continue;

		// 봇이면 통과
		if (IsFakeClient(i))	continue;

		// 인증이 되어 있지 않으면 통과
		if (!IsClientAuthorized(i))	continue;

		// 본인은 통과
		if (i == client)	continue;

		Format(buffer, sizeof(buffer), "%N", i);
		Format(sSendParam, sizeof(sSendParam), "%s||%d", action, GetClientUserId(i));
		mMain.AddItem(sSendParam, buffer);

		// 갯수 증가
		count++;
	}

	// 유저가 없을 때
	if (count == 0)
	{
		// '없음' 출력
		Format(buffer, sizeof(buffer), "%t", "global nothing");
		mMain.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}

	// 메뉴 출력
	mMain.Display(client, MENU_TIME_FOREVER);
}


/*******************************************************
 * C A L L B A C K   F U N C T I O N S
*******************************************************/
/**
 * 커맨드 :: 전체 채팅
 *
 * @param client				클라이언트 인덱스
 * @param args					기타
 */
public Action:Command_Say(int client, int args)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Continue;

	// 서버 채팅은 통과
	if (client == 0)	return Plugin_Continue;

	// 메세지 받고 맨 끝 따옴표 제거
	char sMsg[256];

	GetCmdArgString(sMsg, sizeof(sMsg));
	sMsg[strlen(sMsg)-1] = '\x0';

	// 파라메터 추출 후 분리
	char sMainCmd[32];
	char sParamStr[4][64];
	int sParamIdx;

	sParamIdx = SplitString(sMsg[1], " ", sMainCmd, sizeof(sMainCmd));
	ExplodeString(sMsg[1 + sParamIdx], " ", sParamStr, sizeof(sParamStr), sizeof(sParamStr[]));
	if (sParamIdx == -1)
	{
		strcopy(sMainCmd, sizeof(sMainCmd), sMsg[1]);
		strcopy(sParamStr[0], 64, sMsg[1]);
	}

	// 느낌표나 슬래시가 있다면 제거
	ReplaceString(sMainCmd, sizeof(sMainCmd), "!", "", false);
	ReplaceString(sMainCmd, sizeof(sMainCmd), "/", "", false);

	// 메인 메뉴
	if (StrEqual(sMainCmd, DDS_ENV_USER_MAINMENU, false))
	{
		Menu_Main(client, 0);
	}

	// 팀 채팅 기록 초기화
	dds_bTeamChat[client] = false;

	return dds_hCV_SwitchDisplayChat.BoolValue ? Plugin_Continue : Plugin_Handled;
}

/**
 * 커맨드 :: 팀 채팅
 *
 * @param client				클라이언트 인덱스
 * @param args					기타
 */
public Action:Command_TeamSay(int client, int args)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Continue;

	// 팀 채팅을 했다는 변수를 남기고 일반 채팅과 동일하게 간주
	dds_bTeamChat[client] = true;
	Command_Say(client, args);

	return Plugin_Handled;
}

/**
 * SQL :: 데이터베이스 최초 연결
 *
 * @param db					데이터베이스 연결 핸들
 * @param error					오류 문자열
 * @param data					기타
 */
//public void SQL_GetDatabase(Database db, const char[] error, any data)
public void SQL_GetDatabase(Handle owner, Handle db, const char[] error, any data)
{
	// 데이터베이스 연결 안될 때
	if ((db == null) || (error[0]))
	{
		Log_CodeError(0, 1000, error);
		return;
	}

	// SQL 데이터베이스 핸들 등록
	dds_hSQLDatabase = db;

	if (dds_hSQLDatabase == null)
	{
		Log_CodeError(0, 1001, error);
		return;
	}

	// UTF-8 설정
	dds_hSQLDatabase.SetCharset("utf8");

	// 초기화 및 SQL 데이터베이스에 있는 데이터 로드
	SQL_DDSDatabaseInit();
}

/**
 * SQL :: 일반 SQL 쿼리 오류 발생 시
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param data					기타
 */
public void SQL_ErrorProcess(Database db, DBResultSet results, const char[] error, any data)
{
	/******
	 * @param data				Handle / ArrayList
	 * 					0 - 클라이언트 인덱스(int), 1 - 오류코드(int), 2 - 추가값(char)
	 ******/
	// 타입 변환(*!*핸들 누수가 있는지?)
	ArrayList hData = view_as<ArrayList>(data);

	int client = hData.Get(0);
	int errcode = hData.Get(1);

	delete hData;

	// 오류코드 로그 작성
	if (error[0])	Log_CodeError(client, errcode, error);
}

/**
 * SQL 초기 데이터 :: 아이템 카테고리
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param data					기타
 */
public void SQL_LoadItemCategory(Database db, DBResultSet results, const char[] error, any data)
{
	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(0, 1002, error);
		return;
	}

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 데이터 추가
		dds_eItemCategoryList[dds_iItemCategoryCount + 1][CODE] = results.FetchInt(0);
		results.FetchString(1, dds_eItemCategoryList[dds_iItemCategoryCount + 1][NAME], 64);

		#if defined _DEBUG_
		DDS_PrintToServer(":: DEBUG :: Category Loaded (ID: %d, GloName: %s, TotalCount: %d)", dds_eItemCategoryList[dds_iItemCategoryCount + 1][CODE], dds_eItemCategoryList[dds_iItemCategoryCount + 1][NAME], dds_iItemCategoryCount + 1);
		#endif

		// 아이템 종류 등록 갯수 증가
		dds_iItemCategoryCount++;
	}
}

/**
 * SQL 초기 데이터 :: 아이템 목록
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param data					기타
 */
public void SQL_LoadItemList(Database db, DBResultSet results, const char[] error, any data)
{
	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(0, 1003, error);
		return;
	}

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 데이터 추가
		dds_eItem[dds_iItemCount + 1][INDEX] = results.FetchInt(0);
		results.FetchString(1, dds_eItem[dds_iItemCount + 1][NAME], 64);
		dds_eItem[dds_iItemCount + 1][CATECODE] = results.FetchInt(2);
		dds_eItem[dds_iItemCount + 1][MONEY] = RoundFloat(results.FetchInt(3) * dds_hCV_ItemMoneyMultiply.FloatValue);
		dds_eItem[dds_iItemCount + 1][HAVTIME] = results.FetchInt(4);
		results.FetchString(5, dds_eItem[dds_iItemCount + 1][ENV], 256);

		#if defined _DEBUG_
		DDS_PrintToServer(":: DEBUG :: Item Loaded (ID: %d, GloName: %s, CateCode: %d, Money: %d, Time: %d, TotalCount: %d)", dds_eItem[dds_iItemCount + 1][INDEX], dds_eItem[dds_iItemCount + 1][NAME], dds_eItem[dds_iItemCount + 1][CATECODE], dds_eItem[dds_iItemCount + 1][MONEY], dds_eItem[dds_iItemCount + 1][HAVTIME], dds_iItemCount + 1);
		#endif

		// 아이템 등록 갯수 증가
		dds_iItemCount++;
	}
}

/**
 * SQL 유저 :: 유저 정보 로드 딜레이
 *
 * @param timer					타이머 핸들
 * @param client				클라이언트 인덱스
 */
public Action:SQL_Timer_UserLoad(Handle timer, any client)
{
	// 플러그인이 켜져 있을 때에는 작동 안함
	if (!dds_hCV_PluginSwitch.BoolValue)	return Plugin_Stop;

	// 클라이언트 고유 번호 추출
	char sUsrAuthId[20];
	GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

	/** 데이터 로드 **/
	char sSendQuery[512];

	// 프로필 정보
	Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_profile` WHERE `authid` = '%s'", sUsrAuthId);
	dds_hSQLDatabase.Query(SQL_UserLoad, sSendQuery, client);
	// 장착 아이템 정보
	Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_item` WHERE `authid` = '%s' and `aplied` = '1'", sUsrAuthId);
	dds_hSQLDatabase.Query(SQL_UserAppliedItemLoad, sSendQuery, client);
	// 설정 정보
	Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_setting` WHERE `authid` = '%s'", sUsrAuthId);
	dds_hSQLDatabase.Query(SQL_UserSettingLoad, sSendQuery, client);

	return Plugin_Stop;
}

/**
 * SQL 유저 :: 유저 정보 로드
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param client				클라이언트 인덱스
 */
public void SQL_UserLoad(Database db, DBResultSet results, const char[] error, any client)
{
	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(client, 1010, error);
		return;
	}

	// 갯수 파악
	int count;

	// 임시 정보 저장
	int iTempMoney;

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 데이터 추가
		iTempMoney = results.FetchInt(2);

		// 유저 파악 갯수 증가
		count++;

		#if defined _DEBUG_
		DDS_PrintToServer(":: DEBUG :: User Load - Profile Checked (client: %N, Money: %d)", client, iTempMoney);
		#endif
	}

	/** 추후 작업 **/
	char sSendQuery[256];

	// 클라이언트 고유 번호 추출
	char sUsrAuthId[20];
	GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

	if (count == 0)
	{
		/** 등록된 것이 없다면 정보 생성 **/
		// 오류 검출 생성
		ArrayList hMakeErr = CreateArray(8);
		hMakeErr.Push(client);
		hMakeErr.Push(1011);

		// 쿼리 전송
		Format(sSendQuery, sizeof(sSendQuery), 
			"INSERT INTO `dds_user_profile` (`idx`, `authid`, `money`, `ingame`) VALUES (NULL, '%s', '0', '1')", 
			sUsrAuthId);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErr);

		#if defined _DEBUG_
		DDS_PrintToServer(":: DEBUG :: User Load - Make Profile (client: %N)", client);
		#endif
	}
	else if (count == 1)
	{
		/** 등록된 것이 있다면 정보 로드 및 갱신 **/
		// 오류 검출 생성
		ArrayList hMakeErr = CreateArray(8);
		hMakeErr.Push(client);
		hMakeErr.Push(1012);

		// 금액 로드
		dds_iUserMoney[client] = iTempMoney;

		// 인게임 처리
		Format(sSendQuery, sizeof(sSendQuery), "UPDATE `dds_user_profile` SET `ingame` = '1' WHERE `authid` = '%s'", sUsrAuthId);
		dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErr);

		#if defined _DEBUG_
		DDS_PrintToServer(":: DEBUG :: User Load - Update Profile (client: %N)", client);
		#endif
	}
	else
	{
		/** 잘못된 정보 **/
		Log_CodeError(client, 1014, "The number of this user profile db must be one.");
	}
}

/**
 * SQL 유저 :: 유저 장착 아이템 정보 로드
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param client				클라이언트 인덱스
 */
public void SQL_UserAppliedItemLoad(Database db, DBResultSet results, const char[] error, any client)
{
	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(client, 1015, error);
		return;
	}

	// 갯수 파악
	int count;

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 데이터 로드
		int iDBIdx = results.FetchInt(0);
		int iItIdx = results.FetchInt(2);

		for (int i = 0; i <= dds_iItemCategoryCount; i++)
		{
			// '전체'는 있을 수 없지만 혹시 모르니까 제외
			if (i == 0)	continue;

			// 해당 항목이 아닌 경우 제외
			if (dds_eItem[iItIdx][CATECODE] != dds_eItemCategoryList[i][CODE])	continue;

			dds_iUserAppliedItem[client][i][DBIDX] = iDBIdx;
			dds_iUserAppliedItem[client][i][ITEMIDX] = iItIdx;

			// 장착 아이템 파악 갯수 증가
			count++;

			#if defined _DEBUG_
			DDS_PrintToServer(":: DEBUG :: User Load - Applied Item (client: %N, dbidx: %d, itemidx: %d)", client, iDBIdx, iItIdx);
			#endif

			break;
		}
	}

	#if defined _DEBUG_
	if (count == 0)	DDS_PrintToServer(":: DEBUG :: User Load - Applied Item (client: %N, NO APPLIED ITEMS)", client);
	#endif
}

/**
 * SQL 유저 :: 유저 설정 정보 로드
 *
 * @param db					데이터베이스 연결 핸들
 * @param results				결과 쿼리
 * @param error					오류 문자열
 * @param client				클라이언트 인덱스
 */
public void SQL_UserSettingLoad(Database db, DBResultSet results, const char[] error, any client)
{
	// 쿼리 오류 검출
	if (db == null || error[0])
	{
		Log_CodeError(client, 1016, error);
		return;
	}

	// 갯수 파악
	int count;

	// 클라이언트 고유 번호 추출
	char sUsrAuthId[20];
	GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

	// 쿼리 결과
	while (results.MoreRows)
	{
		// 제시할 행이 없다면 통과
		if (!results.FetchRow())	continue;

		// 데이터 로드
		char sOneCate[20];
		int iTwoCate;
		char sValue[32];
		results.FetchString(2, sOneCate, sizeof(sOneCate));
		iTwoCate = results.FetchInt(3);
		results.FetchString(4, sValue, sizeof(sValue));

		/**********************************************************
		 * sOneCate :: 첫 분류 항목
		 * 
		 * 'sys-status' - 시스템 설정(iTwoCate ~ , sValue ~ )
		 * 'item-status' - 아이템 종류 활성 상태(iTwoCate ~ 아이템 종류 코드, sValue ~ 값[0과 1])
		 *
		 **********************************************************/
		if (StrEqual(sOneCate, "sys-status", false))
		{
			/*********************************
			 * 시스템 설정
			 *********************************/
			// 
		}
		else if (StrEqual(sOneCate, "item-status", false))
		{
			/*********************************
			 * 아이템 활성 정보
			 *********************************/
			// 현재 등록되어 있는 아이템 종류 목록과 똑같이 로드
			for (int i = 0; i <= dds_iItemCategoryCount; i++)
			{
				// 있을 수 없지만 '전체' 항목은 제외
				if (i == 0)	continue;

				// 두 번째 항목이 등록되어 있는 아이템 종류 코드와 다른 경우는 제외
				if (iTwoCate != dds_eItemCategoryList[i][CODE])	continue;

				// 등록되어 있는 아이템 종류 코드의 인덱스로 기준잡아 상태 설정
				dds_eUserItemCGStatus[client][i][CATECODE] = dds_eItemCategoryList[i][CODE];
				dds_eUserItemCGStatus[client][i][VALUE] = view_as<bool>(StringToInt(sValue));

				// 갯수 증가
				count++;

				#if defined _DEBUG_
				DDS_PrintToServer(":: DEBUG :: User Load - Setting ~ Load ItemStatus (client: %N, catelistidx: %d, catecode: %d)", client, i, dds_eItemCategoryList[i][CODE]);
				#endif

				break;
			}
		}
	}

	// 갯수가 없을 때
	if (count == 0)
	{
		/** 아이템 활성 정보 생성 **/
		for (int i = 0; i <= dds_iItemCategoryCount; i++)
		{
			// '전체' 항목 통과
			if (i == 0)	continue;

			// 오류 검출 생성
			ArrayList hMakeErrT = CreateArray(8);
			hMakeErrT.Push(client);
			hMakeErrT.Push(1017);

			// 쿼리 전송
			char sSendQuery[256];
			Format(sSendQuery, sizeof(sSendQuery), 
				"INSERT INTO `dds_user_setting` (`idx`, `authid`, `onecate`, `twocate`, `setvalue`) VALUES (NULL, '%s', 'item-status', '%d', '1')", 
				sUsrAuthId, dds_eItemCategoryList[i][CODE]);
			dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErrT);

			// 데이터 변경
			dds_eUserItemCGStatus[client][i][CATECODE] = dds_eItemCategoryList[i][CODE];
			dds_eUserItemCGStatus[client][i][VALUE] = true;

			#if defined _DEBUG_
			DDS_PrintToServer(":: DEBUG :: User Load - Setting ~ Make ItemStatus (client: %N, catelistidx, catecode: %d)", client, i, dds_eItemCategoryList[i][CODE]);
			#endif
		}
	}
}


/**
 * 메뉴 핸들 :: 메인 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlMain(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			case 1:
			{
				// 내 프로필
				Menu_Profile(client);
			}
			case 2:
			{
				// 내 장착 아이템
				Menu_CurItem(client);
			}
			case 3:
			{
				// 내 인벤토리
				Menu_Inven(client, 0);
			}
			case 4:
			{
				// 아이템 구매
				Menu_BuyItem(client);
			}
			case 5:
			{
				// 설정
				Menu_Setting(client);
			}
			case 9:
			{
				// 플러그인 정보
				Menu_PluginInfo(client);
			}
		}
	}
}

/**
 * 메뉴 핸들 :: 프로필 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlProfile(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			default:
			{
				// 없음
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 내 장착 아이템 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlCurItem(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 등록된 아이템 종류 코드 ('전체' 없음)
		 */
		// 클라이언트 구분
		char sUsrAuthId[20];
		GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

		// 파라메터 생성
		ArrayList sSendParam = CreateArray(12);
		sSendParam.Push(client);
		sSendParam.Push(iInfo);

		// 쿼리 전송
		char sSendQuery[256];
		Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_item` WHERE `authid` = '%s'", sUsrAuthId);
		dds_hSQLDatabase.Query(Menu_CurItem_CateIn, sSendQuery, sSendParam);
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 내 장착 아이템-종류 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlCurItem_CateIn(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sExpStr[3][16];
		ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

		/**
		 * sExpStr
		 * 
		 * @Desc [0] - 데이터베이스 번호([2]가 0일 경우: 아이템 종류 코드), [1] - 아이템 번호([2]가 0일 경우: 아이템 종류 코드), [2] 장착 행동 구분
		 */
		switch (StringToInt(sExpStr[2]))
		{
			case 0:
			{
				// 장착 해제
				System_DataProcess(client, "curitem-cancel", sExpStr[1]);
			}
			case 1:
			{
				// 장착 가능한 것들
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d||%d", StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
				System_DataProcess(client, "curitem-use", sSendParam);
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_CurItem(client);
		}
	}
}

/**
 * 메뉴 핸들 :: 내 인벤토리 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlInven(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 등록된 아이템 종류 코드
		 */
		// 클라이언트 구분
		char sUsrAuthId[20];
		GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

		// 파라메터 생성
		ArrayList sSendParam = CreateArray(12);
		sSendParam.Push(client);
		sSendParam.Push(iInfo);

		// 쿼리 전송
		char sSendQuery[256];
		Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_item` WHERE `authid` = '%s'", sUsrAuthId);
		dds_hSQLDatabase.Query(Menu_Inven_CateIn, sSendQuery, sSendParam);
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 내 인벤토리-종류 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlInven_CateIn(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sExpStr[2][16];
		ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

		/**
		 * sExpStr
		 * 
		 * @Desc ('||' 기준 배열 분리) [0] - 데이터베이스 번호, [1] - 아이템 번호
		 */
		Menu_Inven_ItemDetail(client, StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Inven(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 내 인벤토리-정보 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlInven_ItemDetail(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sExpStr[3][16];
		ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

		/**
		 * sExpStr
		 * 
		 * @Desc ('||' 기준 배열 분리) [0] - 데이터베이스 번호, [1] - 아이템 번호, [2] - 행동(1 - 사용 / 2 - 판매 / 3 - 선물 / 4 - 버리기)
		 */
		switch (StringToInt(sExpStr[2]))
		{
			case 1:
			{
				// 사용
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d||%d", StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
				System_DataProcess(client, "inven-use", sSendParam);
			}
			case 2:
			{
				// 되팔기
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d||%d", StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
				System_DataProcess(client, "inven-resell", sSendParam);
			}
			case 3:
			{
				// 선물
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d||%d", StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
				Menu_ItemGift(client, sSendParam);
			}
			case 4:
			{
				// 버리기
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d||%d", StringToInt(sExpStr[0]), StringToInt(sExpStr[1]));
				System_DataProcess(client, "inven-drop", sSendParam);
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			// 선택한 아이템 종류 항목으로 돌아가게 처리
			char sInfo[32];
			menu.GetItem(item, sInfo, sizeof(sInfo));

			// 파라메터 분리
			char sExpStr[3][16];
			ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

			// 클라이언트 구분
			char sUsrAuthId[20];
			GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

			// 파라메터 생성
			ArrayList sSendParam = CreateArray(6);
			sSendParam.Push(client);
			sSendParam.Push(dds_eItem[StringToInt(sExpStr[1])][CATECODE]);

			// 쿼리 전송
			char sSendQuery[256];
			Format(sSendQuery, sizeof(sSendQuery), "SELECT * FROM `dds_user_item` WHERE `authid` = '%s'", sUsrAuthId);
			dds_hSQLDatabase.Query(Menu_Inven_CateIn, sSendQuery, sSendParam);
		}
	}
}

/**
 * 메뉴 핸들 :: 아이템 구매 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlBuyItem(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 등록된 아이템 종류 코드
		 */
		Menu_BuyItem_CateIn(client, iInfo);
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 아이템 구매-종류 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlBuyItem_CateIn(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 등록된 아이템 번호
		 */
		Menu_BuyItem_ItemDetail(client, iInfo);
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_BuyItem(client);
		}
	}
}

/**
 * 메뉴 핸들 :: 아이템 구매-정보 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlBuyItem_ItemDetail(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sGetParam[3][8];
		ExplodeString(sInfo, "||", sGetParam, sizeof(sGetParam), sizeof(sGetParam[]));

		/**
		 * sGetParam
		 * 
		 * @Desc ('||' 기준 배열 분리) [0] - 아이템 번호, [1] - 아이템 종류 코드, [2] 행동(1 - 확인 / 2- 취소)
		 */
		switch (StringToInt(sGetParam[2]))
		{
			case 1:
			{
				// 확인
				char sSendParam[32];
				Format(sSendParam, sizeof(sSendParam), "%d", StringToInt(sGetParam[0]));
				System_DataProcess(client, "buy", sSendParam);
			}
			case 2:
			{
				// 취소
				// 없음(그냥 닫게 만듬)
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			// 선택한 아이템 종류 항목으로 돌아가게 처리
			char sInfo[32];
			menu.GetItem(item, sInfo, sizeof(sInfo));

			// 파라메터 분리
			char sGetParam[3][8];
			ExplodeString(sInfo, "||", sGetParam, sizeof(sGetParam), sizeof(sGetParam[]));

			Menu_BuyItem_CateIn(client, StringToInt(sGetParam[1]));
		}
	}
}


/**
 * 메뉴 핸들 :: 설정 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlSetting(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			/**
			 * iInfo
			 * 
			 * @Desc 1 - 시스템 설정, 2 - 아이템 활성화 상태 설정
			 */
			case 1:
			{
				// 시스템 설정
				Menu_Setting_System(client);
			}
			case 2:
			{
				// 아이템 설정
				Menu_Setting_Item(client);
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 설정-시스템 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlSetting_System(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			/**
			 * iInfo
			 * 
			 * @Desc 아직 없음
			 */
			case 1:
			{
				// 아직 없음
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Setting(client);
		}
	}
}

/**
 * 메뉴 핸들 :: 설정-아이템 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlSetting_Item(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 등록된 아이템 종류 인덱스
		 */
		// 클라이언트 고유 번호 추출
		char sUsrAuthId[20];
		GetClientAuthId(client, AuthId_SteamID64, sUsrAuthId, sizeof(sUsrAuthId));

		/** 실제 값 변경 **/
		if (dds_eUserItemCGStatus[client][iInfo][VALUE])
		{
			dds_eUserItemCGStatus[client][iInfo][VALUE] = false;

			// 오류 검출 생성
			ArrayList hMakeErr = CreateArray(8);
			hMakeErr.Push(client);
			hMakeErr.Push(1022);

			// 데이터베이스 값 변경
			char sSendQuery[256];
			Format(sSendQuery, sizeof(sSendQuery), 
				"UPDATE `dds_user_setting` SET `setvalue` = '%d' WHERE `authid` = '%s' and `onecate` = 'item-status' and `twocate` = '%d'", 
				0, sUsrAuthId, dds_eUserItemCGStatus[client][iInfo][CATECODE]);
			dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErr);
		}
		else
		{
			dds_eUserItemCGStatus[client][iInfo][VALUE] = true;

			// 오류 검출 생성
			ArrayList hMakeErr = CreateArray(8);
			hMakeErr.Push(client);
			hMakeErr.Push(1022);

			// 데이터베이스 값 변경
			char sSendQuery[256];
			Format(sSendQuery, sizeof(sSendQuery), 
				"UPDATE `dds_user_setting` SET `setvalue` = '%d' WHERE `authid` = '%s' and `onecate` = 'item-status' and `twocate` = '%d'", 
				1, sUsrAuthId, dds_eUserItemCGStatus[client][iInfo][CATECODE]);
			dds_hSQLDatabase.Query(SQL_ErrorProcess, sSendQuery, hMakeErr);
		}

		// 다시 메뉴 출력
		Menu_Setting_Item(client);
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Setting(client);
		}
	}
}

/**
 * 메뉴 핸들 :: 플러그인 정보 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlPluginInfo(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		/**
		 * iInfo
		 * 
		 * @Desc 1 - 명령어 정보, 2 - 개발자 정보, 3 - 저작권 정보
		 */
		if ((iInfo > 0) && (iInfo < 4))
		{
			Menu_PluginInfo_Detail(client, iInfo);
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_Main(client, 0);
		}
	}
}

/**
 * 메뉴 핸들 :: 플러그인 정보-세부 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlPluginInfo_Detail(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			/**
			 * iInfo
			 * 
			 * @Desc 없음
			 */
			default:
			{
				// 없음
			}
		}
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Menu_PluginInfo(client);
		}
	}
}

/**
 * 메뉴 핸들 :: 아이템 선물 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlItemGift(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sExpStr[3][32];
		ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

		/**
		 * sExpStr
		 * 
		 * @Desc ('##' 기준 배열 분리) [0] - 대상 클라이언트 유저 ID, [1] - 추가 파라메터
		 *
		 */
		char sSendParam[32];
		Format(sSendParam, sizeof(sSendParam), "%s||%d", sExpStr[1], StringToInt(sExpStr[0]));
		System_DataProcess(client, "inven-gift", sSendParam);
	}
}

/**
 * 메뉴 핸들 :: 관리자 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlAdmin(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));
		int iInfo = StringToInt(sInfo);

		switch (iInfo)
		{
			case 1:
			{
				// 금액 주기
			}
			case 2:
			{
				// 금액 빼앗기
			}
			case 3:
			{
				// 아이템 주기
				Menu_Admin_Item(client, "item-give");
			}
			case 4:
			{
				// 아이템 빼앗기
				Menu_Admin_Item(client, "item-seize");
			}
		}
	}
}

/**
 * 메뉴 핸들 :: 관리자 아이템-대상 메뉴 핸들러
 *
 * @param menu				메뉴 핸들
 * @param action			메뉴 액션
 * @param client 			클라이언트 인덱스
 * @param item				메뉴 아이템 소유 문자열
 */
public Main_hdlAdmin_Item(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}

	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(item, sInfo, sizeof(sInfo));

		// 파라메터 분리
		char sExpStr[2][32];
		ExplodeString(sInfo, "||", sExpStr, sizeof(sExpStr), sizeof(sExpStr[]));

		/**
		 * sExpStr
		 * 
		 * @Desc ('##' 기준 배열 분리) [0] - 행동 구분, [1] - 대상 클라이언트 유저 ID
		 *
		 */
		char sSendParam[32];
		Format(sSendParam, sizeof(sSendParam), "%s||%d", sExpStr[0], StringToInt(sExpStr[1]));
		// 
	}
}


/*******************************************************
 * N A T I V E  &  F O R W A R D  F U N C T I O N S
*******************************************************/
/**
 * Native :: DDS_IsPluginOn
 *
 * @brief	DDS 플러그인의 활성화 여부
*/
public int Native_DDS_IsPluginOn(Handle:plugin, numParams)
{
	return dds_hCV_PluginSwitch.BoolValue;
}

/**
 * Native :: DDS_GetClientMoney
 *
 * @brief	클라이언트의 금액 반환
*/
public int Native_DDS_GetClientMoney(Handle:plugin, numParams)
{
	int client = GetNativeCell(1);

	// 클라이언트가 인증 절차를 밝았는지의 여부
	if (!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is not authorized.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	// 클라이언트가 봇인지 여부
	if (IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is a bot. We don't support this bot client.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	return dds_iUserMoney[client];
}

/**
 * Native :: DDS_GetClientAppliedDB
 *
 * @brief	클라이언트가 현재 장착한 아이템의 데이터베이스 번호 반환
*/
public int Native_DDS_GetClientAppliedDB(Handle:plugin, numParams)
{
	int client = GetNativeCell(1);
	int catecode = GetNativeCell(2);

	// 클라이언트가 인증 절차를 밝았는지의 여부
	if (!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is not authorized.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	// 클라이언트가 봇인지 여부
	if (IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is a bot. We don't support this bot client.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	// 전달받은 아이템 종류 번호가 0 이상인지 여부
	if (catecode <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s catecode %d should be more than 0.", DDS_ENV_CORE_CHAT_GLOPREFIX, catecode);
		return -1;
	}

	return dds_iUserAppliedItem[client][catecode][DBIDX];
}

/**
 * Native :: DDS_GetClientAppliedItem
 *
 * @brief	클라이언트가 현재 장착한 아이템 번호 반환
*/
public int Native_DDS_GetClientAppliedItem(Handle:plugin, numParams)
{
	int client = GetNativeCell(1);
	int catecode = GetNativeCell(2);

	// 클라이언트가 인증 절차를 밝았는지의 여부
	if (!IsClientAuthorized(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is not authorized.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	// 클라이언트가 봇인지 여부
	if (IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s client %d is a bot. We don't support this bot client.", DDS_ENV_CORE_CHAT_GLOPREFIX, client);
		return -1;
	}

	// 전달받은 아이템 종류 번호가 0 이상인지 여부
	if (catecode <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s catecode %d should be more than 0.", DDS_ENV_CORE_CHAT_GLOPREFIX, catecode);
		return -1;
	}

	return dds_iUserAppliedItem[client][catecode][ITEMIDX];
}