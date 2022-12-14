register fD {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	ifun:4 = NOP;
	rA:4 = REG_NONE;
	rB:4 = REG_NONE;
	valC:64 = 0x0;
	valP:64 = 0x0;
}

register dE {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	ifun:4 = NOP;
	valC:64 = 0x0;
	valA:64 = 0x0;
	valB:64 = 0x0;
	dstM:4 = REG_NONE;
	dstE:4 = REG_NONE;
	valP:64 = 0x0;
}

register eM {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	valA:64 = 0x0;
	valB:64 = 0x0;
	cnd:1 = 0;
	valE:64 = 0x0;
	dstM:4 = REG_NONE;
	dstE:4 = REG_NONE;
	valP:64 = 0x0;
}

register mW {
	stat:3 = STAT_AOK;
	icode:4 = NOP;
	valM:64 = 0x0;
	valE:64 = 0x0;
	dstM:4 = REG_NONE;
	dstE:4 = REG_NONE;
	valP:64 = 0x0;
}

########## the PC and condition codes registers #############
register fF {
	predPC:64 = 0;
}

wire loadUse:1;
loadUse = [
	(E_icode == MRMOVQ) && ((E_dstM == reg_srcA) || (E_dstM == reg_srcB))	: 1;
	(E_icode == POPQ) && ((E_dstM == reg_srcA) || (E_dstM == reg_srcB))	: 1;
	1									: 0;
];

wire mispredicted:1;
mispredicted = [
	E_icode == JXX && !e_cnd	: 1;
	1				: 0;
];

wire ret_present:1;
ret_present = D_icode == RET || E_icode == RET || M_icode == RET;

stall_F = loadUse || ret_present;
stall_D = loadUse;
bubble_D = mispredicted || (!loadUse && ret_present);
bubble_E = mispredicted || loadUse;

register cC {
	SF:1 = 0;
	ZF:1 = 1;
}
########## Fetch ############# fD
pc = [
	M_icode == JXX && !M_cnd	: M_valP;
	W_icode == RET			: W_valM;
	1				: F_predPC;
];

f_stat = [
	f_icode == HALT : STAT_HLT;
	f_icode > 0xb : STAT_INS;
	1 : STAT_AOK;
];

f_icode = i10bytes[4..8];
f_ifun = i10bytes[0..4];
f_rA = i10bytes[12..16];
f_rB = i10bytes[8..12];

f_valC = [
	f_icode in { JXX, CALL }	: i10bytes[8..72];
	1				: i10bytes[16..80];
];

wire offset:64;
offset = [
	f_icode in { HALT, NOP, RET }		: 1;
	f_icode in { RRMOVQ, OPQ, PUSHQ, POPQ } : 2;
	f_icode in { JXX, CALL }		: 9;
	1 					: 10;
];
f_valP = [
	M_icode == JXX && !M_cnd	: M_valP + offset;
	1				: F_predPC + offset;
];
f_predPC = [
	f_stat != STAT_AOK		: pc;
	f_icode in { JXX, CALL }	: f_valC;
	W_icode == RET			: pc + offset;
	1				: f_valP;
];

########## Decode ############# dE
d_stat = D_stat;
d_icode = D_icode;
d_ifun = D_ifun;
d_valC = D_valC;

reg_srcA = [
	D_icode in { RRMOVQ, IRMOVQ, RMMOVQ, OPQ, PUSHQ, CALL } 	: D_rA;
	1								: REG_NONE;
];
reg_srcB = [
	D_icode in { RRMOVQ, IRMOVQ, RMMOVQ, MRMOVQ, OPQ }	: D_rB;
	D_icode in { CALL, RET, PUSHQ, POPQ }			: REG_RSP;
	1							: REG_NONE;
];

d_valA = [
	D_icode in { JXX, CALL }	: D_valP;
	reg_srcA == REG_NONE		: 0;
	reg_srcA == e_dstE		: e_valE;
	reg_srcA == m_dstE		: m_valE;
	reg_srcA == m_dstM		: m_valM;
	reg_srcA == W_dstE		: W_valE;
	reg_srcA == W_dstM		: W_valM;
	1				: reg_outputA;
];
d_valB = [
	reg_srcB == REG_NONE	: 0;
	reg_srcB == e_dstE	: e_valE;
	reg_srcB == m_dstE	: m_valE;
	reg_srcB == m_dstM	: m_valM;
	reg_srcB == W_dstE	: W_valE;
	reg_srcB == W_dstM	: W_valM;
	1			: reg_outputB;
];

d_dstM = [
	D_icode in { MRMOVQ, POPQ }		: D_rA;
	1					: REG_NONE;
];
d_dstE = [
	D_icode in { IRMOVQ, RRMOVQ, OPQ }	: D_rB;
	D_icode in { CALL, RET, PUSHQ, POPQ }	: REG_RSP;
	1					: REG_NONE;
];

d_valP = D_valP;
########## Execute ############# eM
e_stat = E_stat;
e_icode = E_icode;
e_valA = E_valA;
e_valB = E_valB;

wire op1:64;
op1 = [
	E_icode in { IRMOVQ, RMMOVQ, MRMOVQ }	: E_valC;
	E_icode in { RRMOVQ, OPQ }		: E_valA;
	1					: 8;
];
wire op2:64;
op2 = [
	E_icode in { RRMOVQ, IRMOVQ }	: 0;
	1				: E_valB;
];
wire alu:64;
alu = [
	E_icode in { PUSHQ, CALL }		: op2 - op1;
	E_icode == OPQ && E_ifun == SUBQ 	: op2 - op1;
	E_icode == OPQ && E_ifun == ANDQ 	: op2 & op1;
	E_icode == OPQ && E_ifun == XORQ	: op2 ^ op1;
	1					: op2 + op1;
];
c_ZF = [
	E_icode == OPQ	: (alu == 0);
	1		: C_ZF;
];
c_SF = [
	E_icode == OPQ	: (alu >= 0x8000000000000000);
	1		: C_SF;
];
e_cnd = [
	E_ifun == LE	: C_SF || C_ZF;
	E_ifun == LT	: C_SF;
	E_ifun == EQ	: C_ZF;
	E_ifun == NE	: !C_ZF;
	E_ifun == GE	: !C_SF || C_ZF;
	E_ifun == GT	: !C_SF & !C_ZF;
	1		: 1			#JMP/RRMOVQ
];
e_valE = alu;

e_dstM = E_dstM;
e_dstE = [
	(E_icode == CMOVXX) && (!e_cnd)	: REG_NONE;
	1				: E_dstE;
];

e_valP = E_valP;
########## Memory ############# mW
m_stat = M_stat;
m_icode = M_icode;

mem_readbit = M_icode in { MRMOVQ, POPQ, RET };
mem_writebit = M_icode in { RMMOVQ, PUSHQ, CALL };
mem_addr = [
	M_icode in { MRMOVQ, RMMOVQ, PUSHQ, CALL }	: M_valE;
	M_icode in { POPQ, RET }			: M_valE - 8;
	1						: M_valB;
];
mem_input = M_valA;

m_valM = mem_output;
m_valE = M_valE;

m_dstM = M_dstM;
m_dstE = M_dstE;

m_valP = M_valP;
########## Writeback #############
reg_dstM = W_dstM;
reg_dstE = W_dstE;

reg_inputM = [
	W_icode in { MRMOVQ, POPQ, RET }	: W_valM;
	1					: 0xBADBADBAD;
];
reg_inputE = W_valE;

Stat = W_stat;

