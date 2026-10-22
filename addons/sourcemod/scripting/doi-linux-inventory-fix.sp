#include <sourcemod>
#include <dhooks>
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name="doi-linux-inventory-fix", author="server-go",
    description="Route post-BattlEye Windows inventory messages to the native DOI validator",
    version="0.1.2"
};

DynamicDetour g_Find, g_Receive, g_Result;
Address g_AntiVtable, g_InventoryVtable, g_BattleyeState;
int g_Routed, g_Received, g_Results, g_Missing;
char g_Log[PLATFORM_MAX_PATH];

int ReadInt(Address ptr, int offset=0) {
    return LoadFromAddress(ptr+view_as<Address>(offset), NumberType_Int32);
}
Address ReadPtr(Address ptr, int offset=0) {
    return view_as<Address>(ReadInt(ptr, offset));
}
bool Enabled() {
    return g_BattleyeState!=Address_Null &&
        LoadFromAddress(g_BattleyeState+view_as<Address>(4),NumberType_Int8)==0;
}
void State(const char[] stage) {
    LogToFileEx(g_Log, "[DLIF] %s routed=%d received=%d callbacks=%d missing=%d",
        stage,g_Routed,g_Received,g_Results,g_Missing);
}
public void OnPluginStart() {
    char game[16]; GetGameFolderName(game,sizeof(game));
    if (!StrEqual(game,"doi")) SetFailState("DOI Linux 32-bit only");
    BuildPath(Path_SM,g_Log,sizeof(g_Log),"logs/doi-linux-inventory-fix.log");
    GameData data=new GameData("doi-linux-inventory-fix");
    if (data==null) SetFailState("Missing verified gamedata");
    Address find=data.GetMemSig("FindMessage");
    Address antiType=data.GetMemSig("AntiGetType");
    Address invType=data.GetMemSig("InventoryGetType");
    Address antiVt=data.GetMemSig("AntiVtable");
    Address invVt=data.GetMemSig("InventoryVtable");
    Address receive=data.GetMemSig("EngineReceive");
    Address result=data.GetMemSig("OnResult");
    Address battleyeCheck=data.GetMemSig("BattleyeIsEnabled");
    g_BattleyeState=data.GetMemSig("BattleyeState");
    if (find==Address_Null || antiType==Address_Null || invType==Address_Null ||
        antiVt==Address_Null || invVt==Address_Null || receive==Address_Null ||
        result==Address_Null || g_BattleyeState==Address_Null ||
        battleyeCheck==Address_Null) SetFailState("Unrecognized engine symbols");
    // These guards pin the offsets below to the audited Linux engine implementation.
    if (ReadInt(find)!=0x89c03155 || ReadInt(find,4)!=0x835657e5 ||
        ReadInt(antiType)!=0x0013b855 || ReadInt(invType)!=0x0014b855 ||
        ReadInt(antiType,4)!=0xe5890000 || ReadInt(invType,4)!=0xe5890000)
        SetFailState("Engine build differs from the audited 19/20 protocol");
    if (ReadInt(battleyeCheck)!=0x8be58955 || ReadInt(battleyeCheck,7)!=0x0440b60f)
        SetFailState("Unexpected BattlEye runtime state layout");
    g_AntiVtable=antiVt+view_as<Address>(8);
    g_InventoryVtable=invVt+view_as<Address>(8);
    if (ReadPtr(g_AntiVtable,32)!=antiType || ReadPtr(g_InventoryVtable,32)!=invType)
        SetFailState("Unexpected message vtable layout");
    if (!Enabled()) SetFailState("Requires BattlEye disabled");
    g_Find=new DynamicDetour(find,CallConv_THISCALL,ReturnType_Int,ThisPointer_Address);
    g_Find.AddParam(HookParamType_Int);
    g_Receive=new DynamicDetour(receive,CallConv_THISCALL,ReturnType_Bool,ThisPointer_Ignore);
    g_Receive.AddParam(HookParamType_ObjectPtr);
    g_Result=new DynamicDetour(result,CallConv_THISCALL,ReturnType_Void,ThisPointer_Ignore);
    g_Result.AddParam(HookParamType_ObjectPtr);
    delete data;
    if (!g_Find.Enable(Hook_Post,OnFind) || !g_Receive.Enable(Hook_Pre,OnReceive) ||
        !g_Result.Enable(Hook_Post,OnResult)) SetFailState("Could not attach compatibility hooks");
    RegServerCmd("doi-linux-inventory-fix_status",Status);
    State("loaded");
}
public void OnPluginEnd() {
    if (g_Find!=null) g_Find.Disable(Hook_Post,OnFind);
    if (g_Receive!=null) g_Receive.Disable(Hook_Pre,OnReceive);
    if (g_Result!=null) g_Result.Disable(Hook_Post,OnResult);
    State("unloaded");
}
public void OnMapStart() {
    State("map_start");
}
public MRESReturn OnFind(Address channel,DHookReturn ret,DHookParam params) {
    if (params.Get(1)!=19 || !Enabled()) return MRES_Ignored;
    Address original=view_as<Address>(ret.Value);
    if (original==Address_Null || ReadPtr(original)!=g_AntiVtable) return MRES_Ignored;
    int count=ReadInt(channel,0x421c);
    Address messages=ReadPtr(channel,0x4210);
    if (count<1 || count>128 || messages==Address_Null) return MRES_Ignored;
    for (int i=0;i<count;i++) {
        Address message=ReadPtr(messages,i*4);
        if (message!=Address_Null && ReadPtr(message)==g_InventoryVtable) {
            // Use the existing registered object, parser, handler and Steam ownership checks.
            ret.Value=view_as<int>(message);
            g_Routed++;
            if (g_Routed<=8) State("route_windows19_to_inventory20");
            return MRES_Override;
        }
    }
    g_Missing++;
    if (g_Missing<=3) State("inventory_message_missing");
    return MRES_Ignored;
}
public MRESReturn OnReceive(DHookReturn ret,DHookParam params) {
    g_Received++;
    if (g_Received<=8) State("native_inventory_receive");
    return MRES_Ignored;
}
public MRESReturn OnResult(DHookParam params) {
    g_Results++;
    if (g_Results<=16) State("native_result_processed");
    return MRES_Ignored;
}
public Action Status(int argc) {
    PrintToServer("[DLIF] enabled=%d routed=%d received=%d callbacks=%d missing=%d",
        Enabled(),g_Routed,g_Received,g_Results,g_Missing);
    return Plugin_Handled;
}
