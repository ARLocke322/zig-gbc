pub const Instruction = enum(u8) {
    NOP,
    LD_r16_n16,
    LD_r16_A,

    LD_A_r16,
    LD_n16_SP,
    // ------
    INC_r16,
    DEC_r16,
    ADD_HL_r16,
    // ------
    LD_r8_n8,
    // -----
    INC_r8,
    DEC_r8,
    // ---
    RLCA,
    RRCA,
    RLA,
    RRA,
    DAA,
    CPL,
    SCF,
    CCF,

    JR_n8,
    JR_cond_n8,
    STOP,

    // BLOCK 1
    HALT,
    LD_r8_r8,

    // BLOCK 2
    ADD_A_r8,
    ADC_A_r8,
    SUB_A_r8,
    SBC_A_r8,
    AND_A_r8,
    XOR_A_r8,
    OR_A_r8,
    CP_A_r8,

    // BLOCK 3
    ADD_A_n8,
    ADC_A_n8,
    SUB_A_n8,
    SBC_A_n8,
    AND_A_n8,
    XOR_A_n8,
    OR_A_n8,
    CP_A_n8,

    RET_cond,
    RET,
    RETI,

    JP_cond_n16,
    JP_n16,
    JP_HL,

    CALL_cond_n16,
    CALL_n16,

    RST,

    POP_r16stk,
    PUSH_r16stk,

    CB_PREFIX,

    LDH_C_A,
    LDH_n8_A,
    LD_n16_A,
    LDH_A_C,
    LDH_A_n8,
    LD_A_n16,

    ADD_SP_n8,
    LD_HL_SP_n8,
    LD_SP_HL,

    DI,
    EI,
};

pub fn decode(raw_instruction: u8) Instruction {
    return switch (raw_instruction) {
        0x00 => .NOP,
        // -----
        0x01, 0x11, 0x21, 0x31 => .LD_r16_n16,

        0x02, 0x12, 0x22, 0x32 => .LD_r16_A,

        0x0A, 0x1A, 0x2A, 0x3A => .LD_A_r16,
        0x08 => .LD_n16_SP,
        // ------
        0x03, 0x13, 0x23, 0x33 => .INC_r16,
        0x0B, 0x1B, 0x2B, 0x3B => .DEC_r16,
        0x09, 0x19, 0x29, 0x39 => .ADD_HL_r16,
        // ------
        0x06, 0x0E, 0x16, 0x1E, 0x26, 0x2E, 0x3E, 0x36 => .LD_r8_n8,
        // -----
        0x04, 0x0C, 0x14, 0x1C, 0x24, 0x2C, 0x3C, 0x34 => .INC_r8,

        0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x3D, 0x35 => .DEC_r8,
        // ---
        0x07 => .RLCA,
        0x0F => .RRCA,
        0x17 => .RLA,
        0x1F => .RRA,
        0x27 => .DAA,
        0x2F => .CPL,
        0x37 => .SCF,
        0x3F => .CCF,

        0x18 => .JR_n8,
        0x20, 0x28, 0x30, 0x38 => .JR_cond_n8,
        0x10 => .STOP,

        // BLOCK 1
        0x76 => .HALT,
        0x40...0x75, 0x77...0x7F => .LD_r8_r8,

        // BLOCK 2
        0x80...0x87 => .ADD_A_r8,
        0x88...0x8F => .ADC_A_r8,
        0x90...0x97 => .SUB_A_r8,
        0x98...0x9F => .SBC_A_r8,
        0xA0...0xA7 => .AND_A_r8,
        0xA8...0xAF => .XOR_A_r8,
        0xB0...0xB7 => .OR_A_r8,
        0xB8...0xBF => .CP_A_r8,

        // BLOCK 3
        0xC6 => .ADD_A_n8,
        0xCE => .ADC_A_n8,
        0xD6 => .SUB_A_n8,
        0xDE => .SBC_A_n8,
        0xE6 => .AND_A_n8,
        0xEE => .XOR_A_n8,
        0xF6 => .OR_A_n8,
        0xFE => .CP_A_n8,

        0xC0, 0xC8, 0xD0, 0xD8 => .RET_cond,
        0xC9 => .RET,
        0xD9 => .RETI,

        0xC2, 0xCA, 0xD2, 0xDA => .JP_cond_n16,
        0xC3 => .JP_n16,
        0xE9 => .JP_HL,

        0xC4, 0xCC, 0xD4, 0xDC => .CALL_cond_n16,
        0xCD => .CALL_n16,

        0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF => .RST,

        0xC1, 0xD1, 0xE1, 0xF1 => .POP_r16stk,
        0xC5, 0xD5, 0xE5, 0xF5 => .PUSH_r16stk,

        0xCB => .CB_PREFIX,

        0xE2 => .LDH_C_A,
        0xE0 => .LDH_n8_A,
        0xEA => .LD_n16_A,
        0xF2 => .LDH_A_C,
        0xF0 => .LDH_A_n8,
        0xFA => .LD_A_n16,

        0xE8 => .ADD_SP_n8,
        0xF8 => .LD_HL_SP_n8,
        0xF9 => .LD_SP_HL,

        0xF3 => .DI,
        0xFB => .EI,
    };
}
