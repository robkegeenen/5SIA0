| id_abu        | imm_stor                 | id_abu_contr | id_alu             | id_lsu_stor         | id_rf        | imm_x      | imm_y      | id_mul                    |
|               |                          |              |                    |                     |              |            |            |                           |
| .text         | .text                    | .text        | .text              | .text               | .text        | .text      | .text      | .text                     |
|               |                          |              |                    |                     |              |            |            |                           |
| nop           | nopi                     | nop          | nop                | nop                 | nop          | nopi       | nopi       | nop                       |
| ;clear regs   | imm 0x0F ;# regs rf      |              |                    |                     |              | nopi       | nopi       |                           |
|               | nopi                     | srm r3, in0  |                    |                     |              | nopi       | nopi       |                           |
|               | imm -1                   | lrm r3       |                    |                     |              | nopi       | nopi       |                           |
| bcri -3, in0  | imm 0x00000000 ;clr val  | accs r3, in0 |                    |                     |              | nopi       | nopi       |                           |
| ;bds 0        | imm 0x00 ;# regs rf      |              |                    |                     | sra in1, in3 | nopi       | nopi       |                           |
| ;bds 1        | imm 0x00000000 ;in addr  | srm r0, in0  |                    |                     |              | nopi       | imm 0x0F   |                           |
| ;load consts  | imm 0x00004000 ;out addr | srm r1, in0  |                    | srm r0, in2         |              | nopi       | nopi       |                           |
|               | imm 2000 ;np             | srm r2, in0  |                    | lrm r0              |              | nopi       | nopi       |                           |
|               | nopi                     | srm r3, in0  |                    |                     |              | nopi       | nopi       |                           |
| ;main loop    | imm -1                   | lrm r1       |                    |                     |              | nopi       | nopi       |                           |
|               | imm 0x00000000 ;clr val  | accs r0, in3 |                    | lga WORD, out0, in0 |              | nopi       | nopi       |                           |
|               | imm 2                    | srm r0, in1  | and out0, in0, in1 |                     | sra in2, in0 | imm 7104   | nopi       |                           |
|               | imm 2                    | accs r0, in3 | and out0, in0, in1 |                     | lra in2      | imm -35513 | imm -64572 | mulls_sh16 out0, in0, in1 |
|               | imm 2                    | accs r0, in2 | and out0, in0, in1 |                     | lra in2      | imm 71021  | imm 63818  | mulls_sh16 out0, in0, in1 |
|               | imm 2                    | accs r0, in0 | and out0, in0, in1 |                     | lra in2      | imm -71021 | imm -25323 | mulls_sh16 out0, in0, in1 |
|               | imm 2                    | accs r0, in0 | and out0, in0, in1 |                     | lra in2      | imm 35513  | imm 7287   | mulls_sh16 out0, in0, in1 |
|               | imm 6                    | accs r0, in0 | and out0, in0, in1 |                     | lra in2      | imm -7104  | imm -740   | mulls_sh16 out0, in0, in1 |
|               | imm 0                    | accs r0, in0 | and out0, in0, in1 |                     | lra in2      | nopi       | nopi       | mulls_sh16 out0, in0, in1 |
|               | imm -1                   | accs r0, in0 |                    |                     |              | nopi       | nopi       |                           |
|               | nopi                     | accs r3, in0 | sub out1, in3, in2 |                     |              | nopi       | nopi       |                           |
|               | nopi                     | lrm r3       |                    |                     |              | nopi       | nopi       |                           |
| bcri -14, in0 | imm 4                    | lrm r2       |                    |                     |              | nopi       | nopi       |                           |
| ;bds 0        | imm 4                    | accs r1, in0 | and out0, in0, in1 | sga WORD, in0, in1  | sra in2, in0 | nopi       | nopi       |                           |
| ;bds 1        | nopi                     | accs r2, in0 |                    |                     |              | nopi       | nopi       |                           |
| jai 0         | nopi                     | nop          | nop                | nop                 | nop          | nopi       | nopi       | nop                       |
