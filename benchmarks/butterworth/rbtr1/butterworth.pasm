| id_abu_contr | imm_stor  | id_abu_stor | id_lsu_stor        | id_rf_x | imm_x | id_mul_x | id_abu_x | id_rf_y     | imm_y | id_mul_y | id_abu_y |
|              |           |             |                    |         |       |          |          |             |       |          |          |
| .text        | .text     | .text       | .text              | .text   | .text | .text    | .text    | .text       | .text | .text    | .text    |
|              |           |             |                    |         |       |          |          |             |       |          |          |
| nop          | nopi      | nop         | nop                | nop     | nopi  | nop      | nop      | nop         | nopi  | nop      | nop      |
|              | imm 16380 |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | imm 0xAA  | srm r1, in0 |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      | srm r0, in0 |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      | lrm r0      |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      | lrm r1      |                    |         | nopi  |          |          | srm r0, in1 | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          | lrm r0      | nopi  |          |          |
|              | nopi      |             | sga BYTE, in0, in1 |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
|              | nopi      |             |                    |         | nopi  |          |          |             | nopi  |          |          |
| jai 0        | nopi      | nop         | nop                | nop     | nopi  | nop      | nop      | nop         | nopi  | nop      | nop      |
