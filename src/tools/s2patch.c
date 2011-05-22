#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        fprintf(stderr, "Usage: s2patch stage2 output block*\n");
        return 1;
    }
    FILE* stage2 = fopen(argv[1], "rb");
    if (!stage2)
    {
        fprintf(stderr, "Cannot open stage2\n");
        return 1;
    }
    int rv;
    rv = fseek(stage2, 0, SEEK_END);
    if (rv)
    {
        fprintf(stderr, "Unable to get stage2 size\n");
        return 1;
    }
    long stage2_size = ftell(stage2);
    if (stage2_size > 0x4000 || stage2_size < 256 + 4 * 32)
    {
        fprintf(stderr, "Invalide stage2 size: %ld bytes\n", stage2_size);
        return 1;
    }

    FILE* output = fopen(argv[2], "wb");
    rewind(stage2);
    char buffer[4096];
     
    while ((rv = fread(buffer, 1, sizeof(buffer), stage2)) > 0) 
    {
        if ((rv = fwrite(buffer, 1, rv, output)) < 0)
        {
            fprintf(stderr, "output write failed\n");
            return 1;
        }
    }
    if (rv == -1)
    {
        fprintf(stderr, "stage2 read failed\n");
        return 1;
    }
    
    fclose(stage2);
    
    unsigned char block_num = argc - 3;
    if (block_num > 32)
    {
        fprintf(stderr, "Too many blocks: %d, max 32 \n", block_num);
        return 1;
    }
    unsigned int blocks[32];
    
    int i;
    for (i = 0; i < block_num; ++i)
    {

        char* endptr;
        blocks[i] = strtol(argv[3 + i], &endptr, 10);
        if (*endptr != '\0')
        {
            fprintf(stderr, "Invalid block at position %d: should be decimal block number\n", i);
            return 1;
        }
    } 

    fseek(output, 0x100, SEEK_SET);
    for (i = 0; i < block_num; ++i)
    {
        rv = fwrite(blocks + i, 4, 1, output);
    }
    

    fclose(output);
    return 0;
}
