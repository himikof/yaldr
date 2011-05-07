#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv)
{
    if (argc < 4 || argc > 6)
    {
        fprintf(stderr, "Usage: s1patch stage1 output stage2 [drive] [s2start]\n");
        return 1;
    }
    FILE* stage1 = fopen(argv[1], "rb");
    if (!stage1)
    {
        fprintf(stderr, "Cannot open stage1\n");
        return 1;
    }
    int rv;
    rv = fseek(stage1, 0, SEEK_END);
    if (rv)
    {
        fprintf(stderr, "Unable to get stage1 size\n");
        return 1;
    }
    long stage1_size = ftell(stage1);
    if (stage1_size != 0x200)
    {
        fprintf(stderr, "Invalide stage1 size: %ld bytes\n", stage1_size);
        return 1;
    }

    FILE* stage2 = fopen(argv[3], "rb");
    if (!stage2)
    {
        fprintf(stderr, "Cannot open stage2\n");
        return 1;
    }
    rv = fseek(stage2, 0, SEEK_END);
    if (rv)
    {
        fprintf(stderr, "Unable to get stage2 size\n");
        return 1;
    }
    long stage2_size = ftell(stage2);
    fclose(stage2);
    FILE* output = fopen(argv[2], "wb");
    rewind(stage1);
    char buffer[4096];
     
    while ((rv = fread(buffer, 1, sizeof(buffer), stage1)) > 0) 
    {
        if ((rv = fwrite(buffer, 1, rv, output)) < 0)
        {
            fprintf(stderr, "output write failed\n");
            return 1;
        }
    }
    if (rv == -1)
    {
        fprintf(stderr, "stage1 read failed\n");
        return 1;
    }
    
    fclose(stage1);
    
    unsigned char drive_num;
    if (argc > 4)
    {
        char* endptr;
        drive_num = strtol(argv[4], &endptr, 16);
        if (*endptr != '\0')
        {
            fprintf(stderr, "Invalid drive number: should be hex byte\n");
            return 1;
        }
    }
    else
        drive_num = 0xFF;
    
    long stage2_start;
    if (argc > 5)
    {
        char* endptr;
        stage2_start = strtol(argv[5], &endptr, 10);
        if (*endptr != '\0')
        {
            fprintf(stderr, "Invalid s2start: should be decimal block number\n");
            return 1;
        }
    }
    else
        stage2_start = (stage1_size >> 9) + ((stage1_size & 0x1FF) ? 1 : 0);

    int stage2_blocks = (stage2_size >> 9) + ((stage2_size & 0x1FF) ? 1 : 0);
    
    fseek(output, 428, SEEK_SET);
    rv = fwrite(&stage2_start, 4, 1, output);
    rv = fwrite(&stage2_blocks, 2, 1, output);
    rv = fwrite(&drive_num, 1, 1, output);
    

    fclose(output);
    return 0;
}
