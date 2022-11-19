/*
 *  output.m
 *  SocPowerBuddy
 *
 *  Created by BitesPotatoBacks on 8/5/22.
 *  Copyright (c) 2022 BitesPotatoBacks.
 */

#include "socpwrbud.h"

static NSString* decfrmt(float);

/*
 * Output for plain text
 */
void textOutput(iorep_data*     iorep,
                static_data*    sd,
                variating_data* vd,
                bool_data*      bd,
                cmd_data*       cmd,
                unsigned int    current_loop,
                int start_time) {
   
    if (current_loop == 0)
    {
        fprintf(cmd->file_out, "Timestamp,");
        fprintf(cmd->file_out, "4-Core %s ECPU,Core 0,Core 1,Core 2,Core 3,", (char*)[sd->extra[2] UTF8String]);
        fprintf(cmd->file_out, "4-Core %s PCPU,Core 4,Core 5,Core 6,Core 7,", (char*)[sd->extra[3] UTF8String]);
        fprintf(cmd->file_out, "GPU,GPU Power\n");

    }
    int num_col = 13;
    int uptime = getUptimeInMilliseconds() - start_time;

    num_col--; 
    fprintf(cmd->file_out, "%d,", uptime);
    
    for (int i = 0; i < [vd->cluster_freqs count]; i++) {
        if (([sd->complex_freq_channels[i] rangeOfString:@"ECPU"].location != NSNotFound) ||
            ([sd->complex_freq_channels[i] rangeOfString:@"PCPU"].location != NSNotFound)) {
        
            num_col--;
            fprintf(cmd->file_out, "%s,", [decfrmt((float)(fabs([vd->cluster_freqs[i] floatValue] * cmd->freq_measure))) UTF8String]);
            
            if (i <= ([sd->cluster_core_counts count]-1)) {
                for (int ii = 0; ii < [sd->cluster_core_counts[i] intValue]; ii++) {
                    num_col--;
                    if (num_col == 0)
                    {
                        fprintf(cmd->file_out, "%s",  [decfrmt((float)(fabs([vd->core_freqs[i][ii] floatValue] * cmd->freq_measure))) UTF8String]);
                    }
                    else
                    {
                        fprintf(cmd->file_out, "%s,",  [decfrmt((float)(fabs([vd->core_freqs[i][ii] floatValue] * cmd->freq_measure))) UTF8String]);
                    }
                }
            }
        } else if ([sd->complex_freq_channels[i] rangeOfString:@"GPU"].location != NSNotFound) {
            num_col -= 2;
            if (num_col == 0)
            {
                fprintf(cmd->file_out, "%s,", [decfrmt((float)(fabs([vd->cluster_freqs[i] floatValue] * cmd->freq_measure))) UTF8String]);   
                fprintf(cmd->file_out, "%s", [decfrmt((float)([vd->cluster_pwrs[i] floatValue] * cmd->power_measure)) UTF8String]); 
            }
            else
            {
                fprintf(cmd->file_out, "%s,", [decfrmt((float)(fabs([vd->cluster_freqs[i] floatValue] * cmd->freq_measure))) UTF8String]);   
                fprintf(cmd->file_out, "%s,", [decfrmt((float)([vd->cluster_pwrs[i] floatValue] * cmd->power_measure)) UTF8String]); 
            }
        }
    }
    fprintf(cmd->file_out, "\n");
}

/*
 * Output for plist
 */
void plistOutput(iorep_data*     iorep,
                 static_data*    sd,
                 variating_data* vd,
                 bool_data*      bd,
                 cmd_data*       cmd,
                 unsigned int    current_loop) {
    
    unsigned int current_core = 0;
    
    fprintf(cmd->file_out, "<key>processor</key><string>%s</string>\n", [sd->extra[0] UTF8String]);
    fprintf(cmd->file_out, "<key>soc_id</key><string>%s</string>\n", [sd->extra[1] UTF8String]);
    fprintf(cmd->file_out, "<key>sample</key><integer>%d</integer>\n", current_loop + 1);
    
    for (int i = 0; i < [vd->cluster_freqs count]; i++) {
        if ((bd->ecpu && [sd->complex_freq_channels[i] rangeOfString:@"ECPU"].location != NSNotFound) ||
            (bd->pcpu && [sd->complex_freq_channels[i] rangeOfString:@"PCPU"].location != NSNotFound) ||
            (bd->gpu && [sd->complex_freq_channels[i] rangeOfString:@"GPU"].location != NSNotFound)) {
        
            char* microarch = "Unknown";
            
            if ([sd->complex_freq_channels[i] rangeOfString:@"ECPU"].location != NSNotFound) microarch = (char*)[sd->extra[2] UTF8String];
            else if ([sd->complex_freq_channels[i] rangeOfString:@"PCPU"].location != NSNotFound) microarch = (char*)[sd->extra[3] UTF8String];
            
            if ([sd->complex_freq_channels[i] rangeOfString:@"CPU"].location != NSNotFound) {
                fprintf(cmd->file_out, "<key>%s</key>\n<dict>\n", [sd->complex_freq_channels[i] UTF8String]);
                fprintf(cmd->file_out, "\t<key>microarch</key><string>%s</string>\n", microarch);
                fprintf(cmd->file_out, "\t<key>core_cnt</key><integer>%d</integer>\n", [sd->cluster_core_counts[i] intValue]);
                
                /* instructions metrics are only available on CPU clusters */
                if (bd->intstrcts) {
                    float retired = [vd->cluster_instrcts_ret[i] floatValue];
                    
                    if (retired > 0) {
                        fprintf(cmd->file_out, "\t<key>instrcts_ret</key><real>%.f</real>\n", retired);
                        fprintf(cmd->file_out, "\t<key>instrcts_per_clk</key><real>%.5f</real>\n", retired / [vd->cluster_instrcts_clk[i] floatValue]);
                    } else {
                        fprintf(cmd->file_out, "\t<key>instrcts_ret</key><real>0</real>\n");
                        fprintf(cmd->file_out, "\t<key>instrcts_per_clk</key><real>0</real>\n");
                    }
                    
                    fprintf(cmd->file_out, "\t<key>cycles_spent</key><integer>%ld</integer>\n", [vd->cluster_instrcts_clk[i] longValue]);
                }
            } else {
                fprintf(cmd->file_out, "\t<key>GPU</key>\n\t<dict>\n");
                fprintf(cmd->file_out, "\t<key>core_cnt</key><integer>%d</integer>\n", sd->gpu_core_count);
            }

            /*
             * printing outputs based on tuned cmd args
             */
            if (bd->power) fprintf(cmd->file_out, "\t<key>power</key><real>%.2f</real>\n", [vd->cluster_pwrs[i] floatValue]);
            if (bd->freq)  fprintf(cmd->file_out, "\t<key>freq</key><real>%.2f</real>\n", fabs([vd->cluster_freqs[i] floatValue]));
            if (bd->res)   fprintf(cmd->file_out, "\t<key>active_res</key><real>%.2f</real>\n", fabs(100-[vd->cluster_use[i] floatValue]));
            if (bd->idle)  fprintf(cmd->file_out, "\t<key>idle_res</key><real>%.2f</real>\n", fabs([vd->cluster_use[i] floatValue]));
            
            if (bd->dvfm) {
                fprintf(cmd->file_out, "\t<key>dvfm_distrib</key>\n\t<dict>\n");

                for (int iii = 0; iii < [sd->dvfm_states[i] count]; iii++) {
                    fprintf(cmd->file_out, "\t\t<key>%ld</key>\n\t\t<dict>\n", [sd->dvfm_states[i][iii] longValue]);
                    fprintf(cmd->file_out, "\t\t\t<key>residency</key><real>%.2f</real>\n", [vd->cluster_residencies[i][iii] floatValue]*100);
                    if (bd->dvfm_ms) fprintf(cmd->file_out, "\t\t\t<key>time_ms</key><real>%.f</real>\n", [vd->cluster_residencies[i][iii] floatValue] * cmd->interval);
                    fprintf(cmd->file_out, "\t\t</dict>\n");
                }

                fprintf(cmd->file_out, "\t</dict>\n");
            }
            
            if (i <= ([sd->cluster_core_counts count]-1)) {
                for (int ii = 0; ii < [sd->cluster_core_counts[i] intValue]; ii++) {
                    fprintf(cmd->file_out, "\t<key>core_%d</key>\n\t<dict>\n", current_core);

                    if (bd->power) fprintf(cmd->file_out, "\t\t<key>power</key><real>%.2f</real>\n", [vd->core_pwrs[i][ii] floatValue]);
                    if (bd->freq)  fprintf(cmd->file_out, "\t\t<key>freq</key><real>%.2f</real>\n", fabs([vd->core_freqs[i][ii] floatValue]));
                    if (bd->res)   fprintf(cmd->file_out, "\t\t<key>active_res</key><real>%.2f</real>\n", fabs([vd->core_use[i][ii] floatValue]));
                    if (bd->idle)   fprintf(cmd->file_out, "\t\t<key>idle_res</key><real>%.2f</real>\n", fabs(100-[vd->core_use[i][ii] floatValue]));
                    
                    if (bd->dvfm) {
                        fprintf(cmd->file_out, "\t\t<key>dvfm_distrib</key>\n\t\t<dict>\n");

                        for (int iii = 0; iii < [sd->dvfm_states[i] count]; iii++) {
                            fprintf(cmd->file_out, "\t\t\t<key>%ld</key>\n\t\t\t<dict>\n", [sd->dvfm_states[i][iii] longValue]);
                            fprintf(cmd->file_out, "\t\t\t\t<key>residency</key><real>%.2f</real>\n", [vd->core_residencies[i][ii][iii] floatValue]*100);
                            if (bd->dvfm_ms) fprintf(cmd->file_out, "\t\t\t\t<key>time_ms</key><real>%.f</real>\n", [vd->core_residencies[i][ii][iii] floatValue] * cmd->interval);
                            fprintf(cmd->file_out, "\t\t\t</dict>\n");
                        }

                        fprintf(cmd->file_out, "\t</dict>\n");
                    }
                    
                    fprintf(cmd->file_out, "\t</dict>\n");
                    
                    current_core++;
                }
            }
        }
        
        fprintf(cmd->file_out, "</dict>\n");
    }
}


/*
 * using this to format decimals on plain text output
 */
static NSString* decfrmt(float arg) {
    NSString* string = @"";
    
    if (fmod(arg, 1.f) != 0)
        string = [NSString stringWithFormat:@"%.2f", arg, nil];
    else
        string = [NSString stringWithFormat:@"%.f", arg, nil];

    return string;
}
